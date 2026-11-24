import { redis } from "../../lib/redis.js";
import { pool, withTransaction } from "../../db/pool.js";
import { cartFlushes } from "../../lib/metrics.js";
import { logger } from "../../lib/logger.js";

/**
 * The cart's hot copy lives in a Redis hash per user:
 *
 *   cart:{uid}  ->  __init = 1        (sentinel: hash exists even when empty)
 *                   __ver  = <n>      (bumped on every write)
 *                   <lineKey> = <qty>
 *
 * Every mutation is a Lua script, so read-modify-write is atomic without locks:
 * 100 concurrent "+1" taps give exactly +100 (capped). Each write also adds the
 * uid to `cart:dirty`. The worker drains that set every couple of seconds and
 * writes carts behind to Postgres in batches. Many taps cost one DB write.
 */
const CART_TTL_SECONDS = 30 * 24 * 60 * 60;
export const DIRTY_SET = "cart:dirty";
export const MAX_LINES = 50;
export const MAX_QTY_PER_LINE = 10;

const cartKey = (uid: string) => `cart:{${uid}}`;

export type MutateResult =
  | { ok: true; quantity: number; version: number }
  | { ok: false; reason: "NOT_LOADED" | "TOO_MANY_LINES" };

// KEYS[1]=cart KEYS[2]=dirty  ARGV: line, mode(incr|set), amount, maxQty, maxLines, uid, ttl
const MUTATE_LUA = `
if redis.call('EXISTS', KEYS[1]) == 0 then return {-1, 0} end
local cur = tonumber(redis.call('HGET', KEYS[1], ARGV[1]) or '0')
local amount = tonumber(ARGV[3])
local nxt = amount
if ARGV[2] == 'incr' then nxt = cur + amount end
if nxt > tonumber(ARGV[4]) then nxt = tonumber(ARGV[4]) end
if cur == 0 and nxt > 0 then
  local lines = redis.call('HLEN', KEYS[1]) - 2
  if lines >= tonumber(ARGV[5]) then return {-2, 0} end
end
if nxt <= 0 then
  redis.call('HDEL', KEYS[1], ARGV[1])
  nxt = 0
else
  redis.call('HSET', KEYS[1], ARGV[1], nxt)
end
local ver = redis.call('HINCRBY', KEYS[1], '__ver', 1)
redis.call('EXPIRE', KEYS[1], ARGV[7])
redis.call('SADD', KEYS[2], ARGV[6])
return {nxt, ver}
`;

// Removes exactly the quantities that were ordered, so items added while
// checkout was running are kept. ARGV: uid, ttl, line1, qty1, line2, qty2...
const CONSUME_LUA = `
if redis.call('EXISTS', KEYS[1]) == 0 then return 0 end
for i = 3, #ARGV, 2 do
  local left = redis.call('HINCRBY', KEYS[1], ARGV[i], -tonumber(ARGV[i + 1]))
  if left <= 0 then redis.call('HDEL', KEYS[1], ARGV[i]) end
end
local ver = redis.call('HINCRBY', KEYS[1], '__ver', 1)
redis.call('EXPIRE', KEYS[1], ARGV[2])
redis.call('SADD', KEYS[2], ARGV[1])
return ver
`;

// Loads the durable copy into Redis unless another request already did.
// ARGV: ttl, version, line1, qty1, ...
const HYDRATE_LUA = `
if redis.call('EXISTS', KEYS[1]) == 1 then return 0 end
redis.call('HSET', KEYS[1], '__init', '1', '__ver', ARGV[2])
for i = 3, #ARGV, 2 do redis.call('HSET', KEYS[1], ARGV[i], ARGV[i + 1]) end
redis.call('EXPIRE', KEYS[1], ARGV[1])
return 1
`;

export interface CartSnapshot {
  version: number;
  lines: Map<string, number>;
}

function parseHash(hash: Record<string, string>): CartSnapshot {
  const lines = new Map<string, number>();
  for (const [field, value] of Object.entries(hash)) {
    if (field === "__init" || field === "__ver") continue;
    lines.set(field, Number(value));
  }
  return { version: Number(hash.__ver ?? 0), lines };
}

/** Rebuilds the Redis copy from Postgres after eviction or a Redis restart. */
async function hydrate(uid: string): Promise<void> {
  const [{ rows: items }, { rows: user }] = await Promise.all([
    pool.query<{ line_key: string; quantity: number }>(
      "SELECT line_key, quantity FROM cart_items WHERE user_id = $1",
      [uid],
    ),
    pool.query<{ cart_version: number }>("SELECT cart_version FROM users WHERE id = $1", [uid]),
  ]);
  const args: (string | number)[] = [CART_TTL_SECONDS, user[0]?.cart_version ?? 0];
  for (const i of items) args.push(i.line_key, i.quantity);
  await redis.eval(HYDRATE_LUA, 1, cartKey(uid), ...args);
}

export async function readCart(uid: string): Promise<CartSnapshot> {
  let hash = await redis.hgetall(cartKey(uid));
  if (!hash.__init) {
    await hydrate(uid);
    hash = await redis.hgetall(cartKey(uid));
  }
  return parseHash(hash);
}

export async function mutateLine(
  uid: string,
  lineKey: string,
  mode: "incr" | "set",
  amount: number,
  maxQty: number,
): Promise<MutateResult> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const [qty, version] = (await redis.eval(
      MUTATE_LUA,
      2,
      cartKey(uid),
      DIRTY_SET,
      lineKey,
      mode,
      amount,
      Math.min(maxQty, MAX_QTY_PER_LINE),
      MAX_LINES,
      uid,
      CART_TTL_SECONDS,
    )) as [number, number];
    if (qty === -1) {
      await hydrate(uid);
      continue;
    }
    if (qty === -2) return { ok: false, reason: "TOO_MANY_LINES" };
    return { ok: true, quantity: qty, version };
  }
  return { ok: false, reason: "NOT_LOADED" };
}

export async function consumeLines(uid: string, lines: { lineKey: string; quantity: number }[]): Promise<void> {
  const args: (string | number)[] = [uid, CART_TTL_SECONDS];
  for (const l of lines) args.push(l.lineKey, l.quantity);
  await redis.eval(CONSUME_LUA, 2, cartKey(uid), DIRTY_SET, ...args);
}

export async function clearCart(uid: string): Promise<void> {
  const snapshot = await readCart(uid);
  await consumeLines(
    uid,
    [...snapshot.lines].map(([lineKey, quantity]) => ({ lineKey, quantity })),
  );
}

/**
 * Write-behind: drains up to `batch` dirty carts and persists them.
 * The version guard (`cart_version < $snapshot`) makes concurrent or
 * out-of-order flushes harmless. An older snapshot can never overwrite a newer one.
 */
export async function flushDirtyCarts(batch = 200): Promise<number> {
  const uids = (await redis.spop(DIRTY_SET, batch)) as string[];
  if (uids.length === 0) return 0;

  const pipeline = redis.pipeline();
  for (const uid of uids) pipeline.hgetall(cartKey(uid));
  const results = (await pipeline.exec()) ?? [];

  let flushed = 0;
  for (const [i, uid] of uids.entries()) {
    const hash = results[i]?.[1] as Record<string, string> | undefined;
    if (!hash?.__init) continue; // evicted: nothing newer than Postgres to save
    const snap = parseHash(hash);
    try {
      await withTransaction(async (db) => {
        const { rowCount } = await db.query(
          "UPDATE users SET cart_version = $2 WHERE id = $1 AND cart_version < $2",
          [uid, snap.version],
        );
        if (rowCount === 0) return; // Postgres already has this version or newer
        const keys = [...snap.lines.keys()];
        await db.query("DELETE FROM cart_items WHERE user_id = $1 AND NOT (line_key = ANY($2::text[]))", [uid, keys]);
        if (keys.length) {
          await db.query(
            `INSERT INTO cart_items (user_id, line_key, product_id, quantity)
             SELECT $1, k, split_part(k, '|', 1), q FROM unnest($2::text[], $3::int[]) AS t(k, q)
             ON CONFLICT (user_id, line_key) DO UPDATE SET quantity = EXCLUDED.quantity, updated_at = now()`,
            [uid, keys, [...snap.lines.values()]],
          );
        }
      });
      flushed++;
    } catch (err) {
      logger.error({ err, uid }, "cart flush failed; will retry");
      await redis.sadd(DIRTY_SET, uid);
    }
  }
  cartFlushes.inc(flushed);
  return flushed;
}
