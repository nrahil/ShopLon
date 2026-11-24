import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pool } from "../../src/db/pool.js";
import { flushDirtyCarts } from "../../src/modules/cart/cart.store.js";
import { expireStaleOrders } from "../../src/modules/orders/orders.service.js";
import { processRefund, reconcilePayments } from "../../src/modules/payments/payments.service.js";
import {
  createProduct,
  idemKey,
  psp,
  setupApp,
  signedWebhook,
  stockOf,
  successEvent,
  teardown,
  tokenFor,
  type App,
} from "./helpers.js";

let app: App;
beforeAll(async () => {
  app = await setupApp();
});
afterAll(async () => teardown(app));

async function addToCart(auth: Record<string, string>, productId: string, quantity = 1) {
  return app.inject({ method: "POST", url: "/v1/cart/items", headers: auth, payload: { productId, quantity } });
}

async function checkout(auth: Record<string, string>, key = idemKey()) {
  return app.inject({ method: "POST", url: "/v1/checkout", headers: { ...auth, "idempotency-key": key } });
}

describe("flash sale: concurrent checkouts never oversell", () => {
  it("50 buyers, 5 units: exactly 5 orders and stock ends at 0", async () => {
    const productId = await createProduct(5);
    const buyers = await Promise.all(Array.from({ length: 50 }, () => tokenFor()));
    for (const b of buyers) expect((await addToCart(b.auth, productId)).statusCode).toBe(200);

    const results = await Promise.all(buyers.map((b) => checkout(b.auth)));
    const codes = results.map((r) => r.statusCode);

    expect(codes.filter((c) => c === 201)).toHaveLength(5);
    expect(codes.filter((c) => c === 409)).toHaveLength(45);
    expect(results.find((r) => r.statusCode === 409)!.json().error.code).toBe("OUT_OF_STOCK");
    expect(await stockOf(productId)).toBe(0);
    const { rows } = await pool.query(
      "SELECT count(*)::int AS n FROM order_items WHERE product_id = $1",
      [productId],
    );
    expect(rows[0].n).toBe(5);
  });
});

describe("idempotent checkout", () => {
  it("a double-tapped checkout creates one order; the retry replays the same response", async () => {
    const productId = await createProduct(10);
    const { uid, auth } = await tokenFor();
    await addToCart(auth, productId, 2);
    const key = idemKey();

    const concurrent = await Promise.all([checkout(auth, key), checkout(auth, key), checkout(auth, key)]);
    const created = concurrent.filter((r) => r.statusCode === 201);
    expect(created.length).toBeGreaterThanOrEqual(1);
    // Losers either got the replayed result or were told to retry.
    for (const r of concurrent) expect([201, 409]).toContain(r.statusCode);

    const retry = await checkout(auth, key);
    expect(retry.statusCode).toBe(201);
    expect(retry.headers["idempotent-replayed"]).toBe("true");
    expect(retry.json().id).toBe(created[0]!.json().id);

    const { rows } = await pool.query("SELECT count(*)::int AS n FROM orders WHERE user_id = $1", [uid]);
    expect(rows[0].n).toBe(1);
    expect(await stockOf(productId)).toBe(8);
  });

  it("rejects reuse of a key for a different request", async () => {
    const productId = await createProduct(10);
    const { auth } = await tokenFor();
    await addToCart(auth, productId);
    const key = idemKey();
    const first = await checkout(auth, key);
    const orderId = first.json().id as string;
    const misuse = await app.inject({
      method: "POST",
      url: `/v1/orders/${orderId}/payments`,
      headers: { ...auth, "idempotency-key": key },
    });
    expect(misuse.statusCode).toBe(422);
  });

  it("requires an idempotency key", async () => {
    const { auth } = await tokenFor();
    const res = await app.inject({ method: "POST", url: "/v1/checkout", headers: auth });
    expect(res.statusCode).toBe(400);
    expect(res.json().error.code).toBe("IDEMPOTENCY_KEY_REQUIRED");
  });
});

describe("payments", () => {
  async function pendingOrder(stock = 10, qty = 1) {
    const productId = await createProduct(stock);
    const user = await tokenFor();
    await addToCart(user.auth, productId, qty);
    const order = (await checkout(user.auth)).json();
    return { ...user, productId, order };
  }

  it("a webhook delivered twice marks the order paid exactly once", async () => {
    const { order, auth } = await pendingOrder();
    expect(order.status).toBe("PENDING_PAYMENT");
    const event = successEvent(order.payment.providerRef, order.totalCents);

    const [a, b] = await Promise.all([
      app.inject({ method: "POST", url: "/v1/webhooks/mock", ...signedWebhook(event), payload: signedWebhook(event).body }),
      app.inject({ method: "POST", url: "/v1/webhooks/mock", ...signedWebhook(event), payload: signedWebhook(event).body }),
    ]);
    expect([a.json().result, b.json().result].sort()).toEqual(["applied", "duplicate"]);

    const after = await app.inject({ method: "GET", url: `/v1/orders/${order.id}`, headers: auth });
    expect(after.json().status).toBe("PAID");
    const { rows } = await pool.query("SELECT count(*)::int AS n FROM outbox WHERE type = 'order.paid' AND aggregate_id = $1", [
      order.id,
    ]);
    expect(rows[0].n).toBe(1);
  });

  it("rejects webhooks with a forged signature", async () => {
    const { order } = await pendingOrder();
    const body = JSON.stringify(successEvent(order.payment.providerRef, order.totalCents));
    const res = await app.inject({
      method: "POST",
      url: "/v1/webhooks/mock",
      headers: { "content-type": "application/json", "mock-signature": `t=${Math.floor(Date.now() / 1000)},v1=${"0".repeat(64)}` },
      payload: body,
    });
    expect(res.statusCode).toBe(400);
  });

  it("refunds instead of fulfilling when the charged amount doesn't match", async () => {
    const { order } = await pendingOrder();
    const event = successEvent(order.payment.providerRef, order.totalCents - 1);
    const wh = signedWebhook(event);
    await app.inject({ method: "POST", url: "/v1/webhooks/mock", headers: wh.headers, payload: wh.body });
    const { rows } = await pool.query("SELECT o.status AS os, p.status AS ps, p.failure_reason FROM orders o JOIN payments p ON p.order_id = o.id WHERE o.id = $1", [
      order.id,
    ]);
    expect(rows[0]).toMatchObject({ os: "PENDING_PAYMENT", ps: "REFUND_PENDING", failure_reason: "amount_mismatch" });
  });

  it("expiry releases stock; a late payment re-reserves it if still available", async () => {
    const { order, productId } = await pendingOrder(3, 2);
    expect(await stockOf(productId)).toBe(1);

    await pool.query("UPDATE orders SET expires_at = now() - interval '1 second' WHERE id = $1", [order.id]);
    await expireStaleOrders();
    expect(await stockOf(productId)).toBe(3);

    const wh = signedWebhook(successEvent(order.payment.providerRef, order.totalCents));
    await app.inject({ method: "POST", url: "/v1/webhooks/mock", headers: wh.headers, payload: wh.body });
    const { rows } = await pool.query("SELECT status FROM orders WHERE id = $1", [order.id]);
    expect(rows[0].status).toBe("PAID");
    expect(await stockOf(productId)).toBe(1);
  });

  it("a late payment for sold-out stock is refunded automatically", async () => {
    const { order, productId } = await pendingOrder(1, 1);
    await pool.query("UPDATE orders SET expires_at = now() - interval '1 second' WHERE id = $1", [order.id]);
    await expireStaleOrders();

    // Someone else buys the released unit.
    const other = await tokenFor();
    await addToCart(other.auth, productId);
    expect((await checkout(other.auth)).statusCode).toBe(201);

    const wh = signedWebhook(successEvent(order.payment.providerRef, order.totalCents));
    await app.inject({ method: "POST", url: "/v1/webhooks/mock", headers: wh.headers, payload: wh.body });
    const { rows } = await pool.query("SELECT o.status, p.id AS payment_id FROM orders o JOIN payments p ON p.order_id = o.id WHERE o.id = $1", [
      order.id,
    ]);
    expect(rows[0].status).toBe("REFUND_PENDING");

    await processRefund(rows[0].payment_id);
    const after = await pool.query("SELECT status FROM orders WHERE id = $1", [order.id]);
    expect(after.rows[0].status).toBe("REFUNDED");
    expect(psp.refunds.some((r) => r.ref === order.payment.providerRef)).toBe(true);
  });

  it("reconciliation recovers a payment whose webhook was lost", async () => {
    const { order } = await pendingOrder();
    psp.intents.get(order.payment.providerRef)!.status = "succeeded";
    await pool.query("UPDATE payments SET created_at = now() - interval '5 minutes' WHERE order_id = $1", [order.id]);
    await reconcilePayments();
    const { rows } = await pool.query("SELECT status FROM orders WHERE id = $1", [order.id]);
    expect(rows[0].status).toBe("PAID");
  });

  it("cancelling releases stock and is rejected once paid", async () => {
    const { order, auth, productId } = await pendingOrder(5, 2);
    const res = await app.inject({ method: "POST", url: `/v1/orders/${order.id}/cancel`, headers: auth });
    expect(res.json().status).toBe("CANCELLED");
    expect(await stockOf(productId)).toBe(5);
    const again = await app.inject({ method: "POST", url: `/v1/orders/${order.id}/cancel`, headers: auth });
    expect(again.statusCode).toBe(409);
  });
});

describe("cart under concurrent writes", () => {
  it("100 parallel +1 taps are applied atomically and capped at 10 per line", async () => {
    const productId = await createProduct(500);
    const { uid, auth } = await tokenFor();
    await Promise.all(Array.from({ length: 100 }, () => addToCart(auth, productId)));
    const cart = (await app.inject({ method: "GET", url: "/v1/cart", headers: auth })).json();
    expect(cart.lines[0].quantity).toBe(10);

    // Write-behind lands the final state in Postgres.
    await flushDirtyCarts();
    const { rows } = await pool.query("SELECT quantity FROM cart_items WHERE user_id = $1", [uid]);
    expect(rows).toEqual([{ quantity: 10 }]);
  });

  it("never lets a user's quantity exceed stock", async () => {
    const productId = await createProduct(3);
    const { auth } = await tokenFor();
    await addToCart(auth, productId, 5);
    const cart = (await app.inject({ method: "GET", url: "/v1/cart", headers: auth })).json();
    expect(cart.lines[0].quantity).toBe(3);
  });

  it("computes prices on the server", async () => {
    const productId = await createProduct(10, 4000);
    const { auth } = await tokenFor();
    await addToCart(auth, productId, 2);
    const cart = (await app.inject({ method: "GET", url: "/v1/cart", headers: auth })).json();
    expect(cart.totals).toEqual({ subtotalCents: 8000, shippingCents: 1000, taxCents: 640, totalCents: 9640 });
  });
});

describe("sessions", () => {
  it("rejects requests without a valid token", async () => {
    expect((await app.inject({ method: "GET", url: "/v1/cart" })).statusCode).toBe(401);
    expect(
      (await app.inject({ method: "GET", url: "/v1/cart", headers: { authorization: "Bearer not.a.jwt" } })).statusCode,
    ).toBe(401);
  });

  it("server-side logout revokes tokens issued before it", async () => {
    const { auth } = await tokenFor();
    expect((await app.inject({ method: "GET", url: "/v1/auth/session", headers: auth })).statusCode).toBe(200);
    await new Promise((r) => setTimeout(r, 1100)); // iat has 1 s resolution
    expect((await app.inject({ method: "POST", url: "/v1/auth/logout", headers: auth })).statusCode).toBe(204);
    expect((await app.inject({ method: "GET", url: "/v1/auth/session", headers: auth })).statusCode).toBe(401);
  });

  it("can't read another user's order", async () => {
    const productId = await createProduct(5);
    const alice = await tokenFor();
    const bob = await tokenFor();
    await addToCart(alice.auth, productId);
    const order = (await checkout(alice.auth)).json();
    const res = await app.inject({ method: "GET", url: `/v1/orders/${order.id}`, headers: bob.auth });
    expect(res.statusCode).toBe(404);
  });
});
