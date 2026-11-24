import { Worker } from "bullmq";
import { pool } from "./db/pool.js";
import { logger } from "./lib/logger.js";
import { queueConnection, redis } from "./lib/redis.js";
import { purgeIdempotencyKeys } from "./http/idempotency.js";
import { flushDirtyCarts } from "./modules/cart/cart.store.js";
import { expireStaleOrders, markShipped } from "./modules/orders/orders.service.js";
import { EVENTS_QUEUE, eventsQueue, relayOutbox, type EventJob } from "./modules/outbox/relay.js";
import { processRefund, reconcilePayments } from "./modules/payments/payments.service.js";

/**
 * Background worker. It runs separately from the API so slow or bursty
 * background work never competes with request latency, and the two scale
 * independently.
 *
 * Every periodic task below is safe to run on many replicas at once
 * (SKIP LOCKED, SPOP and version guards), so no leader election is needed:
 * add worker replicas to add throughput.
 */
const SHIP_DELAY_MS = 60_000;

let stopping = false;

function every(name: string, intervalMs: number, task: () => Promise<number>) {
  const loop = async () => {
    while (!stopping) {
      const started = Date.now();
      try {
        const n = await task();
        if (n > 0) logger.info({ task: name, n, ms: Date.now() - started }, "task processed items");
      } catch (err) {
        logger.error({ err, task: name }, "periodic task failed");
      }
      await new Promise((r) => setTimeout(r, Math.max(0, intervalMs - (Date.now() - started))));
    }
  };
  void loop();
}

every("cart-write-behind", 2_000, () => flushDirtyCarts());
every("outbox-relay", 500, () => relayOutbox());
every("expire-orders", 10_000, () => expireStaleOrders());
every("reconcile-payments", 30_000, () => reconcilePayments());
every("purge-idempotency-keys", 60 * 60_000, () => purgeIdempotencyKeys());

/** Consumers for domain events. Each handler must be idempotent (at-least-once delivery). */
const consumer = new Worker<EventJob>(
  EVENTS_QUEUE,
  async (job) => {
    const { type, payload } = job.data;
    switch (type) {
      case "order.paid":
        logger.info({ orderId: payload.orderId }, "order confirmation email sent (simulated)");
        // Simulated fulfilment: ship a minute later. The fixed jobId de-duplicates.
        await eventsQueue().add(
          "order.ship",
          { ...job.data, type: "order.ship" },
          { jobId: `ship-${payload.orderId as string}`, delay: SHIP_DELAY_MS },
        );
        break;
      case "order.ship":
        await markShipped(payload.orderId as string);
        break;
      case "payment.refund_requested":
        await processRefund(payload.paymentId as string);
        break;
      default:
        logger.debug({ type, payload }, "event consumed");
    }
  },
  { connection: queueConnection(), concurrency: 10 },
);
consumer.on("failed", (job, err) => logger.warn({ err, jobId: job?.id, attempts: job?.attemptsMade }, "event job failed"));

logger.info("worker started");

for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, async () => {
    if (stopping) return;
    stopping = true;
    logger.info({ signal }, "worker shutting down");
    await consumer.close(); // waits for in-flight jobs
    await eventsQueue().close();
    await Promise.allSettled([pool.end(), redis.quit()]);
    process.exit(0);
  });
}
