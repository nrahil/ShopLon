import type { PoolClient } from "pg";
import type { ProductRow } from "../catalog/catalog.service.js";
import { PRODUCT_COLUMNS } from "../catalog/catalog.service.js";

export interface Shortage {
  productId: string;
  requested: number;
  available: number;
}

/**
 * Reserves stock for several products atomically.
 *
 * Concurrency model (pessimistic, row-level):
 *  - `SELECT ... FOR NO KEY UPDATE` locks only the rows being bought, so
 *    different products never contend. (NO KEY: inserts that reference the
 *    product through a foreign key, like cart flushes, aren't blocked.)
 *  - Locks are always taken in primary-key order. Two checkouts touching the
 *    same products therefore queue instead of deadlocking (no lock cycles).
 *  - The `CHECK (stock >= 0)` constraint is a last line of defence: even a
 *    buggy code path can't oversell.
 *
 * Under a flash sale, N buyers for K units serialise on one row. Each holds
 * the lock for about a millisecond, and exactly K succeed.
 */
export async function reserveStock(
  db: PoolClient,
  wanted: Map<string, number>,
): Promise<{ ok: true; products: Map<string, ProductRow> } | { ok: false; shortages: Shortage[] }> {
  const ids = [...wanted.keys()].sort();
  const { rows } = await db.query<ProductRow>(
    `SELECT ${PRODUCT_COLUMNS} FROM products WHERE id = ANY($1::text[]) AND active ORDER BY id FOR NO KEY UPDATE`,
    [ids],
  );
  const products = new Map(rows.map((r) => [r.id, r]));

  const shortages: Shortage[] = [];
  for (const id of ids) {
    const requested = wanted.get(id)!;
    const available = products.get(id)?.stock ?? 0;
    if (available < requested) shortages.push({ productId: id, requested, available });
  }
  if (shortages.length) return { ok: false, shortages };

  await db.query(
    `UPDATE products p SET stock = p.stock - t.q, updated_at = now()
     FROM unnest($1::text[], $2::int[]) AS t(id, q) WHERE p.id = t.id`,
    [ids, ids.map((id) => wanted.get(id)!)],
  );
  return { ok: true, products };
}

/**
 * Returns an order's stock to the shelf exactly once. The `stock_reserved`
 * flag is flipped with a compare-and-set, so calling this twice (from
 * cancel and expiry racing, say) releases the stock only once.
 * The caller must already hold the order's row lock.
 */
export async function releaseStock(db: PoolClient, orderId: string): Promise<boolean> {
  const { rowCount } = await db.query(
    "UPDATE orders SET stock_reserved = false WHERE id = $1 AND stock_reserved",
    [orderId],
  );
  if (rowCount === 0) return false;
  const { rows } = await db.query<{ product_id: string; q: number }>(
    `SELECT product_id, sum(quantity)::int AS q FROM order_items WHERE order_id = $1
     GROUP BY product_id ORDER BY product_id`,
    [orderId],
  );
  // Same lock order as reserveStock (by id) to stay deadlock-free.
  await db.query("SELECT id FROM products WHERE id = ANY($1::text[]) ORDER BY id FOR NO KEY UPDATE", [
    rows.map((r) => r.product_id),
  ]);
  await db.query(
    `UPDATE products p SET stock = p.stock + t.q, updated_at = now()
     FROM unnest($1::text[], $2::int[]) AS t(id, q) WHERE p.id = t.id`,
    [rows.map((r) => r.product_id), rows.map((r) => r.q)],
  );
  return true;
}

/** Re-reserves stock for an order whose reservation was released (late payment). */
export async function rereserveStock(db: PoolClient, orderId: string): Promise<boolean> {
  const { rows } = await db.query<{ product_id: string; q: number }>(
    "SELECT product_id, sum(quantity)::int AS q FROM order_items WHERE order_id = $1 GROUP BY product_id",
    [orderId],
  );
  const res = await reserveStock(db, new Map(rows.map((r) => [r.product_id, r.q])));
  if (!res.ok) return false;
  await db.query("UPDATE orders SET stock_reserved = true WHERE id = $1", [orderId]);
  return true;
}
