import type { PoolClient } from "pg";
import { config } from "../../config.js";
import { pool, withTransaction } from "../../db/pool.js";
import { conflict } from "../../lib/errors.js";
import { logger } from "../../lib/logger.js";
import { paymentEvents } from "../../lib/metrics.js";
import { emit } from "../outbox/outbox.js";
import { rereserveStock } from "../orders/inventory.js";
import { getOrder, lockOrder, type OrderDto } from "../orders/orders.service.js";
import { MockProvider } from "./mock.provider.js";
import type { PaymentProvider, ProviderEvent } from "./provider.js";
import { StripeProvider } from "./stripe.provider.js";

let provider: PaymentProvider | null = null;
export function paymentProvider(): PaymentProvider {
  provider ??= config.PAYMENT_PROVIDER === "stripe" ? new StripeProvider() : new MockProvider();
  return provider;
}
/** Test hook: swap in a fake provider. */
export function setPaymentProvider(p: PaymentProvider): void {
  provider = p;
}

interface PaymentRow {
  id: string;
  order_id: string;
  provider: string;
  provider_ref: string | null;
  status: "CREATED" | "SUCCEEDED" | "FAILED" | "REFUND_PENDING" | "REFUNDED";
  amount_cents: number;
  currency: string;
}

/**
 * Starts (or resumes) a payment attempt for a pending order.
 *
 * The external call to the PSP happens outside any DB transaction. Holding row
 * locks across a network call would let a slow PSP stall checkout for everyone.
 * Instead:
 *   1. In a transaction, insert a CREATED payment row (a partial unique index
 *      allows only one open attempt per order).
 *   2. Call the PSP with our payment id as its idempotency key, so a retry after
 *      a crash or timeout returns the same intent instead of creating a second one.
 *   3. Save the PSP reference.
 */
export async function startPayment(uid: string, orderId: string): Promise<OrderDto> {
  const payment = await withTransaction(async (db) => {
    const order = await lockOrder(db, orderId, uid);
    if (order.status !== "PENDING_PAYMENT") {
      throw conflict("ORDER_NOT_PAYABLE", `This order is ${order.status.toLowerCase().replace("_", " ")}`);
    }
    if (order.expires_at.getTime() <= Date.now()) {
      throw conflict("ORDER_EXPIRED", "This order's reservation has expired. Please check out again.");
    }
    const open = await db.query<PaymentRow>("SELECT * FROM payments WHERE order_id = $1 AND status = 'CREATED'", [
      orderId,
    ]);
    if (open.rows[0]) return open.rows[0];
    const { rows } = await db.query<PaymentRow>(
      `INSERT INTO payments (order_id, provider, amount_cents, currency) VALUES ($1, $2, $3, $4) RETURNING *`,
      [orderId, paymentProvider().name, order.total_cents, order.currency.trim()],
    );
    return rows[0]!;
  });

  if (!payment.provider_ref) {
    const created = await paymentProvider().createPayment({
      paymentId: payment.id,
      orderId,
      amountCents: payment.amount_cents,
      currency: payment.currency.trim(),
    });
    await pool.query(
      `UPDATE payments SET provider_ref = $2, client_secret = $3, redirect_url = $4, updated_at = now()
       WHERE id = $1 AND provider_ref IS NULL`,
      [payment.id, created.providerRef, created.clientSecret, created.redirectUrl],
    );
  }
  return getOrder(uid, orderId);
}

export type HandleResult = "applied" | "duplicate" | "unknown_payment" | "ignored" | "noop";

/**
 * Applies a provider event (from a webhook or from reconciliation) exactly once.
 *
 *  - De-duplication: (provider, event_id) is inserted first. A redelivered
 *    event hits the primary key and is acknowledged without side effects.
 *  - Ordering: payment and order rows are locked (FOR UPDATE), so a webhook
 *    racing the expiry sweeper or a cancel is serialised, never interleaved.
 *  - Money safety: amount and currency are checked against what we charged.
 *    Every way a success can arrive "too late" ends in either a paid order
 *    or an automatic refund, never in money taken with nothing delivered.
 */
export async function handleProviderEvent(event: ProviderEvent, source: "webhook" | "reconcile"): Promise<HandleResult> {
  const providerName = paymentProvider().name;
  const result = await withTransaction(async (db): Promise<HandleResult> => {
    const fresh = await db.query(
      "INSERT INTO webhook_events (provider, event_id, type) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
      [providerName, event.eventId, event.kind === "ignored" ? event.type : `payment.${event.kind}`],
    );
    if (fresh.rowCount === 0) return "duplicate";
    if (event.kind === "ignored") return "ignored";

    const { rows } = await db.query<PaymentRow>(
      "SELECT * FROM payments WHERE provider = $1 AND provider_ref = $2 FOR UPDATE",
      [providerName, event.providerRef],
    );
    const payment = rows[0];
    if (!payment) {
      // Not ours (or not saved yet). Forget the event id so a redelivery or
      // reconciliation can still apply it later.
      await db.query("DELETE FROM webhook_events WHERE provider = $1 AND event_id = $2", [providerName, event.eventId]);
      return "unknown_payment";
    }
    const order = await lockOrder(db, payment.order_id);

    if (event.kind === "failed") {
      if (payment.status !== "CREATED") return "noop";
      await db.query("UPDATE payments SET status = 'FAILED', failure_reason = $2, updated_at = now() WHERE id = $1", [
        payment.id,
        event.failureReason ?? "declined",
      ]);
      await emit(db, "payment.failed", order.id, { orderId: order.id, paymentId: payment.id, reason: event.failureReason });
      return "applied";
    }

    // Succeeded.
    if (payment.status === "SUCCEEDED" || payment.status === "REFUND_PENDING" || payment.status === "REFUNDED") {
      return "noop";
    }
    const amountMatches =
      event.amountCents === payment.amount_cents && event.currency.toLowerCase() === payment.currency.trim().toLowerCase();
    if (!amountMatches) {
      logger.error({ paymentId: payment.id, expected: payment.amount_cents, got: event.amountCents }, "payment amount mismatch");
      await requestRefund(db, payment, order.id, "amount_mismatch");
      return "applied";
    }

    await db.query(
      "UPDATE payments SET status = 'SUCCEEDED', failure_reason = NULL, updated_at = now() WHERE id = $1",
      [payment.id],
    );

    switch (order.status) {
      case "PENDING_PAYMENT":
        await setOrderStatus(db, order.id, "PAID");
        await emit(db, "order.paid", order.id, { orderId: order.id, userId: order.user_id, paymentId: payment.id });
        return "applied";
      case "EXPIRED":
        // Paid after the reservation lapsed: honour it if the stock is still there.
        if (await rereserveStock(db, order.id)) {
          await setOrderStatus(db, order.id, "PAID");
          await emit(db, "order.paid", order.id, { orderId: order.id, userId: order.user_id, paymentId: payment.id, late: true });
        } else {
          await setOrderStatus(db, order.id, "REFUND_PENDING");
          await requestRefund(db, payment, order.id, "sold_out_after_expiry");
        }
        return "applied";
      case "CANCELLED":
        await setOrderStatus(db, order.id, "REFUND_PENDING");
        await requestRefund(db, payment, order.id, "order_cancelled");
        return "applied";
      default:
        // Already paid by another attempt (e.g. two tabs). Refund the duplicate.
        await requestRefund(db, payment, order.id, "duplicate_payment");
        return "applied";
    }
  });
  paymentEvents.inc({ source, result });
  return result;
}

async function setOrderStatus(db: PoolClient, orderId: string, status: string): Promise<void> {
  await db.query("UPDATE orders SET status = $2, version = version + 1, updated_at = now() WHERE id = $1", [
    orderId,
    status,
  ]);
}

async function requestRefund(db: PoolClient, payment: PaymentRow, orderId: string, reason: string): Promise<void> {
  await db.query(
    "UPDATE payments SET status = 'REFUND_PENDING', failure_reason = $2, updated_at = now() WHERE id = $1",
    [payment.id, reason],
  );
  await emit(db, "payment.refund_requested", orderId, { orderId, paymentId: payment.id, reason });
}

/** Handles payment.refund_requested. Safe to retry: the PSP call is idempotent. */
export async function processRefund(paymentId: string): Promise<void> {
  const { rows } = await pool.query<PaymentRow>("SELECT * FROM payments WHERE id = $1", [paymentId]);
  const payment = rows[0];
  if (!payment || payment.status !== "REFUND_PENDING" || !payment.provider_ref) return;

  await paymentProvider().refund(payment.provider_ref, payment.amount_cents, `refund_${payment.id}`);

  await withTransaction(async (db) => {
    const order = await lockOrder(db, payment.order_id);
    const { rowCount } = await db.query(
      "UPDATE payments SET status = 'REFUNDED', updated_at = now() WHERE id = $1 AND status = 'REFUND_PENDING'",
      [payment.id],
    );
    if (!rowCount) return;
    if (order.status === "REFUND_PENDING") await setOrderStatus(db, order.id, "REFUNDED");
    await emit(db, "payment.refunded", order.id, { orderId: order.id, paymentId: payment.id });
  });
}

/**
 * Safety net for lost webhooks: asks the PSP about attempts that have been open
 * too long, or that were closed by expiry or cancel while possibly still in
 * flight. Findings go through the same handler as webhooks.
 */
export async function reconcilePayments(batch = 50): Promise<number> {
  const { rows } = await pool.query<PaymentRow>(
    `SELECT * FROM payments
     WHERE provider_ref IS NOT NULL AND provider = $1 AND (
       (status = 'CREATED' AND created_at < now() - interval '1 minute')
       OR (status = 'FAILED' AND failure_reason IN ('order_expired', 'order_cancelled')
           AND updated_at > now() - interval '1 hour')
     )
     ORDER BY updated_at LIMIT $2`,
    [paymentProvider().name, batch],
  );
  let changed = 0;
  for (const p of rows) {
    try {
      const status = await paymentProvider().retrieve(p.provider_ref!);
      if (status.status === "pending") continue;
      if (status.status === "failed" && p.status === "FAILED") continue;
      const res = await handleProviderEvent(
        {
          kind: status.status,
          eventId: `reconcile:${p.id}:${status.status}`,
          providerRef: p.provider_ref!,
          amountCents: status.amountCents,
          currency: status.currency,
          failureReason: status.failureReason,
        },
        "reconcile",
      );
      if (res === "applied") changed++;
    } catch (err) {
      logger.warn({ err, paymentId: p.id }, "reconciliation check failed");
    }
  }
  return changed;
}
