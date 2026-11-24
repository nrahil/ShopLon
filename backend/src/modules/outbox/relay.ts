import { Queue } from "bullmq";
import { withTransaction } from "../../db/pool.js";
import { queueConnection } from "../../lib/redis.js";

export const EVENTS_QUEUE = "domain-events";

export interface EventJob {
  outboxId: number;
  type: string;
  aggregateId: string;
  payload: Record<string, unknown>;
}

let queue: Queue<EventJob> | null = null;
export function eventsQueue(): Queue<EventJob> {
  queue ??= new Queue<EventJob>(EVENTS_QUEUE, {
    connection: queueConnection(),
    defaultJobOptions: {
      attempts: 8,
      backoff: { type: "exponential", delay: 1_000 },
      // Kept for a day so a re-relayed outbox row (same jobId) is de-duplicated.
      removeOnComplete: { age: 24 * 60 * 60 },
      removeOnFail: { age: 7 * 24 * 60 * 60 },
    },
  });
  return queue;
}

/**
 * Moves committed outbox rows onto the queue. SKIP LOCKED lets several relays
 * run side by side without double-publishing. If the process dies after
 * enqueueing but before marking rows published, they're re-sent, and the
 * jobId (= outbox id) makes BullMQ drop the duplicate. Consumers are
 * idempotent as well.
 */
export async function relayOutbox(batch = 200): Promise<number> {
  return withTransaction(async (db) => {
    const { rows } = await db.query<{ id: number; type: string; aggregate_id: string; payload: Record<string, unknown> }>(
      `SELECT id, type, aggregate_id, payload FROM outbox
       WHERE published_at IS NULL ORDER BY id LIMIT $1 FOR UPDATE SKIP LOCKED`,
      [batch],
    );
    if (rows.length === 0) return 0;
    await eventsQueue().addBulk(
      rows.map((r) => ({
        name: r.type,
        data: { outboxId: r.id, type: r.type, aggregateId: r.aggregate_id, payload: r.payload },
        opts: { jobId: `outbox-${r.id}` },
      })),
    );
    await db.query("UPDATE outbox SET published_at = now() WHERE id = ANY($1::bigint[])", [rows.map((r) => r.id)]);
    return rows.length;
  });
}
