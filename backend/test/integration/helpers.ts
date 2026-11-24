import { randomUUID } from "node:crypto";
import { buildApp } from "../../src/http/app.js";
import { pool } from "../../src/db/pool.js";
import { migrate } from "../../src/db/migrate.js";
import { redis } from "../../src/lib/redis.js";
import { mintDevToken } from "../../src/auth/dev-token.js";
import { MockProvider } from "../../src/modules/payments/mock.provider.js";
import type { CreatedPayment, CreatePaymentInput, ProviderStatus } from "../../src/modules/payments/provider.js";
import { setPaymentProvider } from "../../src/modules/payments/payments.service.js";
import { sign } from "../../src/modules/payments/signature.js";

/** Mock adapter whose PSP is in memory, so tests don't need the psp container. Webhook verification is real. */
export class FakePsp extends MockProvider {
  intents = new Map<string, { amount: number; currency: string; status: ProviderStatus["status"] }>();
  refunds: { ref: string; amount: number; key: string }[] = [];

  override async createPayment(input: CreatePaymentInput): Promise<CreatedPayment> {
    const ref = `pi_${input.paymentId.replace(/-/g, "")}`;
    if (!this.intents.has(ref)) this.intents.set(ref, { amount: input.amountCents, currency: input.currency, status: "pending" });
    return { providerRef: ref, clientSecret: `${ref}_secret_x`, redirectUrl: null };
  }
  override async retrieve(ref: string): Promise<ProviderStatus> {
    const i = this.intents.get(ref)!;
    return { status: i.status, amountCents: i.amount, currency: i.currency };
  }
  override async refund(ref: string, amount: number, key: string): Promise<void> {
    if (!this.refunds.some((r) => r.key === key)) this.refunds.push({ ref, amount, key });
  }
}

export const psp = new FakePsp();
setPaymentProvider(psp);

export type App = Awaited<ReturnType<typeof buildApp>>;

export async function setupApp(): Promise<App> {
  await migrate();
  await redis.flushdb();
  await pool.query("INSERT INTO categories (slug, name) VALUES ('test', 'Test') ON CONFLICT DO NOTHING");
  const app = await buildApp();
  await app.ready();
  return app;
}

export async function teardown(app: App) {
  await app.close();
  await Promise.allSettled([pool.end(), redis.quit()]);
}

export async function createProduct(stock: number, priceCents = 2500): Promise<string> {
  const id = `t_${randomUUID().slice(0, 8)}`;
  await pool.query(
    `INSERT INTO products (id, title, category, price_cents, stock) VALUES ($1, $2, 'test', $3, $4)`,
    [id, `Product ${id}`, priceCents, stock],
  );
  return id;
}

export async function stockOf(id: string): Promise<number> {
  const { rows } = await pool.query<{ stock: number }>("SELECT stock FROM products WHERE id = $1", [id]);
  return rows[0]!.stock;
}

export async function tokenFor(uid = `u_${randomUUID().slice(0, 12)}`) {
  return { uid, auth: { authorization: `Bearer ${await mintDevToken(process.env.AUTH_DEV_SECRET!, uid)}` } };
}

export const idemKey = () => randomUUID().replace(/-/g, "");

export function signedWebhook(event: unknown) {
  const body = JSON.stringify(event);
  return {
    body,
    headers: { "content-type": "application/json", "mock-signature": sign(process.env.MOCK_PSP_WEBHOOK_SECRET!, body) },
  };
}

export function successEvent(ref: string, amount: number, currency = "usd") {
  return {
    id: `evt_${randomUUID()}`,
    type: "payment_intent.succeeded",
    data: { id: ref, amount, currency, status: "succeeded" },
  };
}
