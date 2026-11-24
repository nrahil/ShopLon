/**
 * Flash-sale load test against the running docker compose stack.
 *
 *   npm run load:flash-sale -- --buyers 500 --stock 25
 *
 * 1. Creates a product with `stock` units.
 * 2. `buyers` distinct users each add it to their cart.
 * 3. All of them hit "checkout" at the same instant.
 * 4. Winners pay through the mock PSP with a test card; the script waits for
 *    the webhook to mark each order PAID.
 * 5. Verifies the invariants: orders == stock, stock == 0, nothing oversold.
 */
import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import pg from "pg";
import { mintDevToken } from "../src/auth/dev-token.js";

const arg = (name: string, fallback: number) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? Number(process.argv[i + 1]) : fallback;
};
const BUYERS = arg("buyers", 300);
const STOCK = arg("stock", 25);
const API = process.env.API_URL ?? "http://localhost:8080";
const DB = process.env.DATABASE_URL ?? "postgres://shop:shop@localhost:5432/shop";

const env = Object.fromEntries(
  readFileSync(new URL("../.env", import.meta.url), "utf8")
    .split(/\r?\n/)
    .filter((l) => l && !l.startsWith("#") && l.includes("="))
    .map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]),
);
if (!env.AUTH_DEV_SECRET) throw new Error("AUTH_DEV_SECRET missing in backend/.env (see .env.example)");

function percentile(sorted: number[], p: number) {
  return sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))]!.toFixed(0) : "-";
}

async function timed<T>(fn: () => Promise<T>): Promise<[T, number]> {
  const t = performance.now();
  const r = await fn();
  return [r, performance.now() - t];
}

async function inBatches<T, R>(items: T[], size: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const out: R[] = [];
  for (let i = 0; i < items.length; i += size) out.push(...(await Promise.all(items.slice(i, i + size).map(fn))));
  return out;
}

async function main() {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  const productId = `flash_${randomUUID().slice(0, 8)}`;
  await db.query(
    `INSERT INTO products (id, title, category, price_cents, discount_percent, stock, thumbnail)
     SELECT $1, 'Flash Sale Headphones', slug, 4999, 50, $2, 'https://cdn.dummyjson.com/product-images/mobile-accessories/apple-airpods-max-silver/thumbnail.webp'
     FROM categories ORDER BY slug LIMIT 1`,
    [productId, STOCK],
  );
  console.log(`\nFlash sale: ${BUYERS} buyers racing for ${STOCK} units of ${productId}\n`);

  const users = await Promise.all(
    Array.from({ length: BUYERS }, async (_, i) => {
      const uid = `load_${Date.now()}_${i}`;
      return { uid, headers: { authorization: `Bearer ${await mintDevToken(env.AUTH_DEV_SECRET!, uid)}`, "content-type": "application/json" } };
    }),
  );

  // Phase 1: everyone adds to cart (Redis hot path).
  const cartLatency: number[] = [];
  await inBatches(users, 100, async (u) => {
    const [res, ms] = await timed(() =>
      fetch(`${API}/v1/cart/items`, { method: "POST", headers: u.headers, body: JSON.stringify({ productId, quantity: 1 }) }),
    );
    cartLatency.push(ms);
    if (!res.ok) throw new Error(`add to cart failed: ${res.status} ${await res.text()}`);
  });

  // Phase 2: everyone checks out at once.
  const t0 = performance.now();
  const results = await Promise.all(
    users.map(async (u) => {
      const [res, ms] = await timed(() =>
        fetch(`${API}/v1/checkout`, { method: "POST", headers: { ...u.headers, "idempotency-key": randomUUID().replace(/-/g, "") } }),
      );
      return { u, status: res.status, body: (await res.json().catch(() => null)) as any, ms };
    }),
  );
  const wall = performance.now() - t0;
  const byStatus = results.reduce<Record<number, number>>((m, r) => ((m[r.status] = (m[r.status] ?? 0) + 1), m), {});
  const winners = results.filter((r) => r.status === 201);
  const unexpected = results.find((r) => r.status !== 201 && r.status !== 409);
  if (unexpected) console.warn("sample unexpected response:", unexpected.status, JSON.stringify(unexpected.body));
  const checkoutLatency = results.map((r) => r.ms).sort((a, b) => a - b);

  // Phase 3: winners pay at the PSP (card data goes to the PSP, never to our API).
  await Promise.all(
    winners.map(async (w) => {
      const p = w.body.payment;
      const res = await fetch(p.confirmUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ client_secret: p.clientSecret, card: { number: "4242424242424242", exp_month: 12, exp_year: 2034, cvc: "123" } }),
      });
      if (!res.ok) throw new Error(`PSP confirm failed: ${res.status} ${await res.text()}`);
    }),
  );

  // Phase 4: wait for webhooks -> PAID.
  const deadline = Date.now() + 30_000;
  let paid = 0;
  while (Date.now() < deadline) {
    const { rows } = await db.query(
      `SELECT count(*)::int AS n FROM orders o JOIN order_items i ON i.order_id = o.id
       WHERE i.product_id = $1 AND o.status IN ('PAID', 'SHIPPED')`,
      [productId],
    );
    paid = rows[0].n;
    if (paid === winners.length) break;
    await new Promise((r) => setTimeout(r, 250));
  }

  const { rows: stockRows } = await db.query("SELECT stock FROM products WHERE id = $1", [productId]);
  const { rows: sold } = await db.query("SELECT coalesce(sum(quantity),0)::int AS n FROM order_items WHERE product_id = $1", [productId]);
  await db.end();

  const sortedCart = cartLatency.sort((a, b) => a - b);
  console.table({
    "add to cart": { requests: users.length, p50_ms: percentile(sortedCart, 50), p95_ms: percentile(sortedCart, 95), p99_ms: percentile(sortedCart, 99) },
    checkout: { requests: results.length, p50_ms: percentile(checkoutLatency, 50), p95_ms: percentile(checkoutLatency, 95), p99_ms: percentile(checkoutLatency, 99) },
  });
  console.log("checkout responses by status:", byStatus);
  console.log(`checkout burst: ${results.length} requests in ${wall.toFixed(0)} ms (${((results.length / wall) * 1000).toFixed(0)} req/s)`);
  console.log(`orders created: ${winners.length}, paid via webhook: ${paid}`);
  console.log(`units sold: ${sold[0].n}, stock left: ${stockRows[0].stock}`);

  const ok = winners.length === STOCK && sold[0].n === STOCK && stockRows[0].stock === 0 && paid === STOCK;
  console.log(ok ? "\nPASS: no overselling, every winner paid, stock fully consumed." : "\nFAIL: invariants violated");
  process.exit(ok ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
