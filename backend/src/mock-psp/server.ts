/**
 * Mock Payment Service Provider, a stand-in for Stripe so the whole payment
 * flow runs locally with no account. It deliberately behaves like a real,
 * imperfect PSP:
 *   - secret-key auth for server calls, idempotency keys on create and refund
 *   - the browser confirms with a client secret; card data never touches our API
 *   - asynchronous outcome delivered by signed webhook, retried with backoff
 *   - test cards that decline, deliver webhooks twice, or drop them entirely
 *     (to exercise de-duplication and reconciliation)
 */
import Fastify from "fastify";
import cors from "@fastify/cors";
import { randomBytes, timingSafeEqual } from "node:crypto";
import { Redis } from "ioredis";
import { z } from "zod";
import { sign } from "../modules/payments/signature.js";

const env = z
  .object({
    PORT: z.coerce.number().default(8090),
    REDIS_URL: z.string().url(),
    MOCK_PSP_SECRET_KEY: z.string().default("sk_mock_local"),
    MOCK_PSP_WEBHOOK_SECRET: z.string().default("whsec_mock_local"),
    MOCK_PSP_WEBHOOK_URL: z.string().url().default("http://localhost:3000/v1/webhooks/mock"),
    MOCK_PSP_CORS_ORIGINS: z.string().default("http://localhost:5000"),
    MOCK_PSP_PROCESSING_MS: z.coerce.number().default(1200),
  })
  .parse(process.env);

const redis = new Redis(env.REDIS_URL);
const app = Fastify({ logger: { level: "info" } });
const origins = env.MOCK_PSP_CORS_ORIGINS.split(",").map((s) => s.trim());
await app.register(cors, { origin: (o, cb) => cb(null, !o || origins.includes(o)), methods: ["GET", "POST"] });

type Status = "requires_payment_method" | "processing" | "succeeded" | "failed";
interface Intent {
  id: string;
  client_secret: string;
  status: Status;
  amount: number;
  currency: string;
  failure_code?: string;
  refunded?: number;
  metadata: Record<string, string>;
}

const key = (id: string) => `psp:pi:${id}`;
const rid = (prefix: string) => `${prefix}_${randomBytes(12).toString("hex")}`;

async function load(id: string): Promise<Intent | null> {
  const raw = await redis.get(key(id));
  return raw ? (JSON.parse(raw) as Intent) : null;
}
async function save(i: Intent) {
  await redis.set(key(i.id), JSON.stringify(i), "EX", 7 * 24 * 3600);
}
function publicView(i: Intent) {
  const { client_secret: _secret, ...rest } = i;
  return rest;
}

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

function requireSecretKey(auth: string | undefined) {
  if (!auth || !safeEqual(auth, `Bearer ${env.MOCK_PSP_SECRET_KEY}`)) {
    const err = new Error("Invalid API key") as Error & { statusCode: number };
    err.statusCode = 401;
    throw err;
  }
}

/** Runs `create` once per idempotency key, remembering the resulting id for a day. */
async function idempotent(idemKey: string | undefined, create: () => Promise<string>): Promise<string> {
  if (!idemKey) return create();
  const existing = await redis.get(`psp:idem:${idemKey}`);
  if (existing) return existing;
  const id = await create();
  const won = await redis.set(`psp:idem:${idemKey}`, id, "EX", 86400, "NX");
  return won === "OK" ? id : ((await redis.get(`psp:idem:${idemKey}`)) ?? id);
}

// ---------------------------------------------------------------------------
// Server-to-server API (secret key)
// ---------------------------------------------------------------------------
app.post("/v1/payment_intents", async (req) => {
  requireSecretKey(req.headers.authorization);
  const body = z
    .object({ amount: z.number().int().positive(), currency: z.string().length(3), metadata: z.record(z.string(), z.string()).default({}) })
    .parse(req.body);
  const id = await idempotent(req.headers["idempotency-key"] as string | undefined, async () => {
    const pi: Intent = {
      id: rid("pi"),
      client_secret: "",
      status: "requires_payment_method",
      amount: body.amount,
      currency: body.currency,
      metadata: body.metadata,
    };
    pi.client_secret = `${pi.id}_secret_${randomBytes(16).toString("hex")}`;
    await save(pi);
    return pi.id;
  });
  return (await load(id))!;
});

app.get("/v1/payment_intents/:id", async (req, reply) => {
  requireSecretKey(req.headers.authorization);
  const pi = await load((req.params as { id: string }).id);
  return pi ? publicView(pi) : reply.status(404).send({ error: "not_found" });
});

app.post("/v1/refunds", async (req, reply) => {
  requireSecretKey(req.headers.authorization);
  const body = z.object({ payment_intent: z.string(), amount: z.number().int().positive() }).parse(req.body);
  const refundId = await idempotent(req.headers["idempotency-key"] as string | undefined, async () => {
    const pi = await load(body.payment_intent);
    if (!pi || pi.status !== "succeeded") throw Object.assign(new Error("not refundable"), { statusCode: 400 });
    if ((pi.refunded ?? 0) + body.amount > pi.amount) throw Object.assign(new Error("over-refund"), { statusCode: 400 });
    pi.refunded = (pi.refunded ?? 0) + body.amount;
    await save(pi);
    return rid("re");
  });
  return reply.send({ id: refundId, payment_intent: body.payment_intent, amount: body.amount, status: "succeeded" });
});

// ---------------------------------------------------------------------------
// Browser API (client secret): card details go here, never to the shop's API
// ---------------------------------------------------------------------------
const TEST_CARDS: Record<string, { outcome: "succeeded" | "failed"; code?: string; delivery?: "duplicate" | "drop" | "slow" }> = {
  "4242424242424242": { outcome: "succeeded" },
  "4000000000000002": { outcome: "failed", code: "card_declined" },
  "4000000000009995": { outcome: "failed", code: "insufficient_funds" },
  "4000000000000259": { outcome: "succeeded", delivery: "duplicate" },
  "4000000000000341": { outcome: "succeeded", delivery: "drop" },
  "4000000000000077": { outcome: "succeeded", delivery: "slow" },
};

function luhn(num: string): boolean {
  let sum = 0;
  for (let i = 0; i < num.length; i++) {
    let d = Number(num[num.length - 1 - i]);
    if (i % 2 === 1) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 === 0;
}

const confirmBody = z.object({
  client_secret: z.string().min(10).max(200),
  card: z.object({
    number: z.string().transform((s) => s.replace(/\s+/g, "")).pipe(z.string().regex(/^\d{12,19}$/, "invalid card number")),
    exp_month: z.number().int().min(1).max(12),
    exp_year: z.number().int().min(0).max(9999),
    cvc: z.string().regex(/^\d{3,4}$/, "invalid CVC"),
  }),
});

// Atomic state change: a double-clicked "Pay" can only confirm once.
const CLAIM_LUA = `
local raw = redis.call('GET', KEYS[1])
if not raw then return 0 end
local pi = cjson.decode(raw)
if pi.status ~= 'requires_payment_method' then return -1 end
pi.status = 'processing'
redis.call('SET', KEYS[1], cjson.encode(pi), 'KEEPTTL')
return 1
`;

app.post("/v1/payment_intents/:id/confirm", { bodyLimit: 4096 }, async (req, reply) => {
  const { id } = req.params as { id: string };
  const parsed = confirmBody.safeParse(req.body);
  if (!parsed.success) {
    return reply.status(400).send({ error: { code: "invalid_request", message: parsed.error.issues[0]?.message } });
  }
  const { client_secret, card } = parsed.data;
  const pi = await load(id);
  if (!pi || !safeEqual(client_secret, pi.client_secret)) {
    return reply.status(404).send({ error: { code: "resource_missing", message: "No such payment" } });
  }
  if (!luhn(card.number)) {
    return reply.status(402).send({ error: { code: "incorrect_number", message: "Your card number is incorrect." } });
  }
  const year = card.exp_year < 100 ? 2000 + card.exp_year : card.exp_year;
  const now = new Date();
  if (year < now.getFullYear() || (year === now.getFullYear() && card.exp_month < now.getMonth() + 1)) {
    return reply.status(402).send({ error: { code: "expired_card", message: "Your card has expired." } });
  }
  const claimed = await redis.eval(CLAIM_LUA, 1, key(id));
  if (claimed !== 1) {
    return reply.status(409).send({ error: { code: "payment_intent_unexpected_state", message: "This payment was already submitted." } });
  }

  const behaviour = TEST_CARDS[card.number] ?? { outcome: "succeeded" as const };
  setTimeout(() => void settle(id, behaviour), env.MOCK_PSP_PROCESSING_MS);
  // Like 3-D Secure-free Stripe: the browser learns the final status from the shop, not from here.
  return { id, status: "processing" };
});

async function settle(id: string, b: (typeof TEST_CARDS)[string]) {
  const pi = await load(id);
  if (!pi) return;
  pi.status = b.outcome;
  if (b.code) pi.failure_code = b.code;
  await save(pi);

  const event = {
    id: rid("evt"),
    type: b.outcome === "succeeded" ? "payment_intent.succeeded" : "payment_intent.payment_failed",
    created: Math.floor(Date.now() / 1000),
    data: publicView(pi),
  };
  if (b.delivery === "drop") {
    app.log.warn({ id }, "test card: webhook intentionally dropped (reconciliation must catch it)");
    return;
  }
  const delay = b.delivery === "slow" ? 20_000 : 0;
  setTimeout(() => void deliver(event), delay);
  if (b.delivery === "duplicate") setTimeout(() => void deliver(event), delay + 300);
}

/** Delivers a webhook with exponential backoff (1 s, 2 s, 4 s ... ~1 min), like a real PSP. */
async function deliver(event: { id: string }, attempt = 1): Promise<void> {
  const body = JSON.stringify(event);
  try {
    const res = await fetch(env.MOCK_PSP_WEBHOOK_URL, {
      method: "POST",
      headers: { "content-type": "application/json", "mock-signature": sign(env.MOCK_PSP_WEBHOOK_SECRET, body) },
      body,
      signal: AbortSignal.timeout(10_000),
    });
    if (res.ok) {
      app.log.info({ event: event.id, attempt }, "webhook delivered");
      return;
    }
    throw new Error(`status ${res.status}`);
  } catch (err) {
    if (attempt >= 7) {
      app.log.error({ event: event.id, err: String(err) }, "webhook delivery gave up");
      return;
    }
    const wait = 1000 * 2 ** (attempt - 1);
    app.log.warn({ event: event.id, attempt, wait, err: String(err) }, "webhook delivery failed; retrying");
    setTimeout(() => void deliver(event, attempt + 1), wait);
  }
}

app.get("/healthz", async () => ({ status: "ok" }));

await app.listen({ host: "0.0.0.0", port: env.PORT });
