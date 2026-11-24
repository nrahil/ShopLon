import type { PoolClient } from "pg";
import { config } from "../../config.js";
import { pool, withTransaction, type Db } from "../../db/pool.js";
import { AppError, badRequest, conflict, notFound } from "../../lib/errors.js";
import { logger } from "../../lib/logger.js";
import { checkouts } from "../../lib/metrics.js";
import { computeTotals, discounted } from "../../lib/money.js";
import { consumeLines, readCart } from "../cart/cart.store.js";
import { parseLineKey } from "../cart/cart.service.js";
import { emit } from "../outbox/outbox.js";
import { releaseStock, reserveStock } from "./inventory.js";
import type { OrderStatus } from "./order-state.js";
import { sourcesOf } from "./order-state.js";

export interface OrderRow {
  id: string;
  user_id: string;
  status: OrderStatus;
  currency: string;
  subtotal_cents: number;
  shipping_cents: number;
  tax_cents: number;
  total_cents: number;
  item_count: number;
  expires_at: Date;
  stock_reserved: boolean;
  created_at: Date;
  updated_at: Date;
}

interface ItemRow {
  order_id: string;
  product_id: string;
  title: string;
  thumbnail: string;
  unit_price_cents: number;
  quantity: number;
  selected_size: string | null;
  selected_color: string | null;
}

interface PaymentRow {
  id: string;
  order_id: string;
  provider: string;
  provider_ref: string | null;
  status: string;
  amount_cents: number;
  client_secret: string | null;
  redirect_url: string | null;
  failure_reason: string | null;
  created_at: Date;
}

export interface OrderDto {
  id: string;
  status: OrderStatus;
  currency: string;
  subtotalCents: number;
  shippingCents: number;
  taxCents: number;
  totalCents: number;
  itemCount: number;
  expiresAt: string;
  createdAt: string;
  items: {
    productId: string;
    title: string;
    thumbnail: string;
    unitPriceCents: number;
    quantity: number;
    selectedSize: string | null;
    selectedColor: string | null;
  }[];
  payment: {
    id: string;
    provider: string;
    status: string;
    providerRef: string | null;
    clientSecret: string | null;
    redirectUrl: string | null;
    /** Mock PSP only: where the browser posts card details (never to our API). */
    confirmUrl: string | null;
    failureReason: string | null;
  } | null;
}

function toDto(o: OrderRow, items: ItemRow[], payment: PaymentRow | undefined): OrderDto {
  return {
    id: o.id,
    status: o.status,
    currency: o.currency.trim(),
    subtotalCents: o.subtotal_cents,
    shippingCents: o.shipping_cents,
    taxCents: o.tax_cents,
    totalCents: o.total_cents,
    itemCount: o.item_count,
    expiresAt: o.expires_at.toISOString(),
    createdAt: o.created_at.toISOString(),
    items: items.map((i) => ({
      productId: i.product_id,
      title: i.title,
      thumbnail: i.thumbnail,
      unitPriceCents: i.unit_price_cents,
      quantity: i.quantity,
      selectedSize: i.selected_size,
      selectedColor: i.selected_color,
    })),
    payment: payment
      ? {
          id: payment.id,
          provider: payment.provider,
          status: payment.status,
          providerRef: payment.provider_ref,
          // The client secret is only useful while the attempt is open.
          clientSecret: payment.status === "CREATED" ? payment.client_secret : null,
          redirectUrl: payment.status === "CREATED" ? payment.redirect_url : null,
          confirmUrl:
            payment.status === "CREATED" && payment.provider === "mock" && payment.provider_ref
              ? `${config.MOCK_PSP_PUBLIC_URL}/v1/payment_intents/${payment.provider_ref}/confirm`
              : null,
          failureReason: payment.failure_reason,
        }
      : null,
  };
}

/** Loads orders with their items and latest payment attempt, in three queries (no N+1). */
async function hydrateOrders(db: Db, orders: OrderRow[]): Promise<OrderDto[]> {
  if (orders.length === 0) return [];
  const ids = orders.map((o) => o.id);
  const [{ rows: items }, { rows: payments }] = await Promise.all([
    db.query<ItemRow>("SELECT * FROM order_items WHERE order_id = ANY($1::uuid[]) ORDER BY order_id, line_no", [ids]),
    db.query<PaymentRow>(
      `SELECT DISTINCT ON (order_id) * FROM payments WHERE order_id = ANY($1::uuid[])
       ORDER BY order_id, created_at DESC`,
      [ids],
    ),
  ]);
  return orders.map((o) =>
    toDto(
      o,
      items.filter((i) => i.order_id === o.id),
      payments.find((p) => p.order_id === o.id),
    ),
  );
}

export async function getOrder(uid: string, orderId: string, db: Db = pool): Promise<OrderDto> {
  const { rows } = await db.query<OrderRow>("SELECT * FROM orders WHERE id = $1 AND user_id = $2", [orderId, uid]);
  // Another user's order id returns 404 rather than 403, so ids can't be probed.
  if (!rows[0]) throw notFound("Order");
  return (await hydrateOrders(db, rows))[0]!;
}

/** Keyset pagination over (created_at, id), newest first. */
export async function listOrders(
  uid: string,
  opts: { cursor?: string; limit: number },
): Promise<{ items: OrderDto[]; nextCursor: string | null }> {
  let after: [string, string] | null = null;
  if (opts.cursor) {
    const [ts, id] = Buffer.from(opts.cursor, "base64url").toString().split("|");
    if (!ts || !id) throw badRequest("BAD_CURSOR", "Invalid cursor");
    after = [ts, id];
  }
  const { rows } = await pool.query<OrderRow>(
    `SELECT * FROM orders WHERE user_id = $1
       AND ($2::timestamptz IS NULL OR (created_at, id) < ($2::timestamptz, $3::uuid))
     ORDER BY created_at DESC, id DESC LIMIT $4`,
    [uid, after?.[0] ?? null, after?.[1] ?? null, opts.limit + 1],
  );
  const page = rows.slice(0, opts.limit);
  const last = page[page.length - 1];
  return {
    items: await hydrateOrders(pool, page),
    nextCursor:
      rows.length > opts.limit && last
        ? Buffer.from(`${last.created_at.toISOString()}|${last.id}`).toString("base64url")
        : null,
  };
}

/**
 * Turns the cart into an order and reserves stock, in one transaction.
 * Prices come from the locked product rows, never from the client.
 */
export async function createOrderFromCart(uid: string): Promise<OrderRow> {
  const cart = await readCart(uid);
  if (cart.lines.size === 0) throw badRequest("CART_EMPTY", "Your cart is empty");

  const lines = [...cart.lines].map(([lineKey, quantity]) => ({ lineKey, quantity, ...parseLineKey(lineKey) }));
  const wanted = new Map<string, number>();
  for (const l of lines) wanted.set(l.productId, (wanted.get(l.productId) ?? 0) + l.quantity);

  let order: OrderRow;
  try {
    order = await withTransaction(async (db) => {
      const reservation = await reserveStock(db, wanted);
      if (!reservation.ok) {
        throw conflict("OUT_OF_STOCK", "Some items in your cart are no longer available in that quantity", {
          shortages: reservation.shortages,
        });
      }
      const priced = lines.map((l) => {
        const p = reservation.products.get(l.productId)!;
        return { ...l, product: p, unitPriceCents: discounted(p.price_cents, p.discount_percent) };
      });
      const totals = computeTotals(priced);
      const itemCount = priced.reduce((n, l) => n + l.quantity, 0);

      const { rows } = await db.query<OrderRow>(
        `INSERT INTO orders (user_id, currency, subtotal_cents, shipping_cents, tax_cents, total_cents,
                             item_count, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, now() + make_interval(secs => $8))
         RETURNING *`,
        [
          uid,
          config.CURRENCY,
          totals.subtotalCents,
          totals.shippingCents,
          totals.taxCents,
          totals.totalCents,
          itemCount,
          config.RESERVATION_TTL_SECONDS,
        ],
      );
      const created = rows[0]!;
      await db.query(
        `INSERT INTO order_items (order_id, line_no, product_id, title, thumbnail, unit_price_cents,
                                  quantity, selected_size, selected_color)
         SELECT $1, n, pid, t, th, up, q, sz, co
         FROM unnest($2::int[], $3::text[], $4::text[], $5::text[], $6::int[], $7::int[], $8::text[], $9::text[])
           AS x(n, pid, t, th, up, q, sz, co)`,
        [
          created.id,
          priced.map((_, i) => i + 1),
          priced.map((l) => l.productId),
          priced.map((l) => l.product.title),
          priced.map((l) => l.product.thumbnail),
          priced.map((l) => l.unitPriceCents),
          priced.map((l) => l.quantity),
          priced.map((l) => l.size),
          priced.map((l) => l.color),
        ],
      );
      await emit(db, "order.created", created.id, { orderId: created.id, userId: uid, totalCents: totals.totalCents });
      return created;
    });
  } catch (err) {
    checkouts.inc({ outcome: err instanceof AppError ? err.code.toLowerCase() : "error" });
    throw err;
  }
  checkouts.inc({ outcome: "created" });

  // Outside the transaction: the order is safely committed. If this best-effort
  // cleanup fails, the shopper just sees the items still in their cart.
  await consumeLines(uid, lines).catch((err) => logger.error({ err, uid }, "failed to clear ordered cart lines"));
  return order;
}

async function lockOrder(db: PoolClient, orderId: string, uid?: string): Promise<OrderRow> {
  const { rows } = await db.query<OrderRow>(
    `SELECT * FROM orders WHERE id = $1 ${uid ? "AND user_id = $2" : ""} FOR UPDATE`,
    uid ? [orderId, uid] : [orderId],
  );
  if (!rows[0]) throw notFound("Order");
  return rows[0];
}

export async function cancelOrder(uid: string, orderId: string): Promise<OrderDto> {
  return withTransaction(async (db) => {
    const order = await lockOrder(db, orderId, uid);
    if (!sourcesOf("CANCELLED").includes(order.status)) {
      throw conflict("ORDER_NOT_CANCELLABLE", `An order that is ${order.status.toLowerCase()} can't be cancelled`);
    }
    await db.query("UPDATE orders SET status = 'CANCELLED', version = version + 1, updated_at = now() WHERE id = $1", [
      orderId,
    ]);
    await releaseStock(db, orderId);
    await db.query(
      "UPDATE payments SET status = 'FAILED', failure_reason = 'order_cancelled', updated_at = now() WHERE order_id = $1 AND status = 'CREATED'",
      [orderId],
    );
    await emit(db, "order.cancelled", orderId, { orderId, userId: uid });
    return getOrder(uid, orderId, db);
  });
}

/**
 * Expires unpaid orders past their reservation window and releases their stock.
 * FOR UPDATE SKIP LOCKED lets several worker replicas sweep in parallel
 * without blocking each other or processing the same order twice.
 */
export async function expireStaleOrders(batch = 100): Promise<number> {
  return withTransaction(async (db) => {
    const { rows } = await db.query<{ id: string; user_id: string }>(
      `SELECT id, user_id FROM orders
       WHERE status = 'PENDING_PAYMENT' AND expires_at < now()
       ORDER BY expires_at LIMIT $1 FOR UPDATE SKIP LOCKED`,
      [batch],
    );
    for (const o of rows) {
      await db.query("UPDATE orders SET status = 'EXPIRED', version = version + 1, updated_at = now() WHERE id = $1", [
        o.id,
      ]);
      await releaseStock(db, o.id);
      await db.query(
        "UPDATE payments SET status = 'FAILED', failure_reason = 'order_expired', updated_at = now() WHERE order_id = $1 AND status = 'CREATED'",
        [o.id],
      );
      await emit(db, "order.expired", o.id, { orderId: o.id, userId: o.user_id });
    }
    return rows.length;
  });
}

/** Simulated fulfilment, driven by the order.paid event. */
export async function markShipped(orderId: string): Promise<boolean> {
  return withTransaction(async (db) => {
    const { rowCount } = await db.query(
      "UPDATE orders SET status = 'SHIPPED', version = version + 1, updated_at = now() WHERE id = $1 AND status = 'PAID'",
      [orderId],
    );
    if (rowCount) await emit(db, "order.shipped", orderId, { orderId });
    return (rowCount ?? 0) > 0;
  });
}

export { lockOrder };
