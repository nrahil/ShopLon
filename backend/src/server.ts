import { config } from "./config.js";
import { buildApp } from "./http/app.js";
import { pool } from "./db/pool.js";
import { redis } from "./lib/redis.js";
import { logger } from "./lib/logger.js";

/**
 * API process. Stateless: sessions are JWTs, carts live in Redis, everything
 * else is in Postgres. Any number of replicas can run behind the load balancer.
 */
const app = await buildApp();
await app.listen({ host: "0.0.0.0", port: config.PORT });

// Graceful shutdown: stop taking new connections, let in-flight requests
// finish, then close pools. Rolling deploys drop no requests.
let shuttingDown = false;
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, async () => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info({ signal }, "shutting down");
    const force = setTimeout(() => process.exit(1), 15_000).unref();
    try {
      await app.close();
      await Promise.allSettled([pool.end(), redis.quit()]);
    } finally {
      clearTimeout(force);
      process.exit(0);
    }
  });
}
