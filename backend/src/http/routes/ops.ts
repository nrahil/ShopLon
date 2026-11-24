import type { FastifyPluginAsync } from "fastify";
import { pool } from "../../db/pool.js";
import { redis } from "../../lib/redis.js";
import { registry } from "../../lib/metrics.js";

export const opsRoutes: FastifyPluginAsync = async (app) => {
  const noLimit = { config: { rateLimit: false } };

  /** Liveness: the process is up. */
  app.get("/healthz", noLimit, async () => ({ status: "ok" }));

  /** Readiness: dependencies reachable. The load balancer stops routing here if not. */
  app.get("/readyz", noLimit, async (_req, reply) => {
    const checks = await Promise.allSettled([pool.query("SELECT 1"), redis.ping()]);
    const [db, cache] = checks.map((c) => c.status === "fulfilled");
    const ok = db && cache;
    return reply.status(ok ? 200 : 503).send({ status: ok ? "ready" : "degraded", postgres: db, redis: cache });
  });

  /** Prometheus scrape endpoint. nginx doesn't expose it publicly. */
  app.get("/metrics", noLimit, async (_req, reply) =>
    reply.type(registry.contentType).send(await registry.metrics()),
  );
};
