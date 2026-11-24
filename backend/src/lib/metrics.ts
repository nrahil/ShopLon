import client from "prom-client";

/** Prometheus metrics, served on /metrics (blocked from the public by nginx). */
export const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

export const httpDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request latency",
  labelNames: ["method", "route", "status"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
  registers: [registry],
});

export const cacheEvents = new client.Counter({
  name: "cache_events_total",
  help: "Catalogue cache hits and misses",
  labelNames: ["result"],
  registers: [registry],
});

export const cartOps = new client.Counter({
  name: "cart_operations_total",
  help: "Cart writes handled in Redis",
  labelNames: ["op"],
  registers: [registry],
});

export const cartFlushes = new client.Counter({
  name: "cart_flush_users_total",
  help: "Carts written behind to Postgres",
  registers: [registry],
});

export const checkouts = new client.Counter({
  name: "checkouts_total",
  help: "Checkout attempts by outcome",
  labelNames: ["outcome"],
  registers: [registry],
});

export const idempotencyEvents = new client.Counter({
  name: "idempotency_events_total",
  help: "Idempotency key outcomes",
  labelNames: ["result"],
  registers: [registry],
});

export const paymentEvents = new client.Counter({
  name: "payment_events_total",
  help: "Payment webhook and reconciliation outcomes",
  labelNames: ["source", "result"],
  registers: [registry],
});
