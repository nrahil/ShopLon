import type { PoolClient } from "pg";

export type DomainEventType =
  | "order.created"
  | "order.paid"
  | "order.cancelled"
  | "order.expired"
  | "order.shipped"
  | "payment.failed"
  | "payment.refund_requested"
  | "payment.refunded";

/**
 * Records an event in the same transaction as the state change that caused it.
 * If the transaction rolls back, the event never existed. If it commits, the
 * worker's relay is guaranteed to publish it eventually (at-least-once).
 */
export async function emit(
  db: PoolClient,
  type: DomainEventType,
  aggregateId: string,
  payload: Record<string, unknown>,
): Promise<void> {
  await db.query("INSERT INTO outbox (aggregate_id, type, payload) VALUES ($1, $2, $3)", [
    aggregateId,
    type,
    JSON.stringify(payload),
  ]);
}
