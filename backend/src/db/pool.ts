import pg from "pg";
import { config } from "../config.js";
import { logger } from "../lib/logger.js";

// BIGINT comes back as a string by default; our ids and counts fit in a JS number.
pg.types.setTypeParser(pg.types.builtins.INT8, (v) => Number(v));

export const pool = new pg.Pool({
  connectionString: config.DATABASE_URL,
  max: config.DATABASE_POOL_MAX,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
  // Kill runaway queries instead of letting them hold locks and connections.
  statement_timeout: 10_000,
  application_name: process.env.SERVICE_NAME ?? "shoplon",
});

pool.on("error", (err) => logger.error({ err }, "idle postgres client error"));

export type Db = pg.Pool | pg.PoolClient;

const RETRYABLE = new Set([
  "40001", // serialization_failure
  "40P01", // deadlock_detected
]);

/**
 * Runs `fn` inside a transaction. Serialization failures and deadlocks are
 * retried with jittered backoff, so callers can treat them as transient.
 */
export async function withTransaction<T>(fn: (client: pg.PoolClient) => Promise<T>, attempts = 3): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const result = await fn(client);
      await client.query("COMMIT");
      return result;
    } catch (err) {
      await client.query("ROLLBACK").catch(() => undefined);
      const code = (err as { code?: string }).code;
      if (code && RETRYABLE.has(code) && attempt < attempts) {
        const delay = 10 * 2 ** attempt + Math.random() * 25;
        logger.warn({ code, attempt, delay }, "retrying transaction");
        await new Promise((r) => setTimeout(r, delay));
        continue;
      }
      throw err;
    } finally {
      client.release();
    }
  }
}
