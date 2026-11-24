import { Redis } from "ioredis";
import { config } from "../config.js";
import { logger } from "./logger.js";

/** General-purpose client for cache, cart, rate limits and session revocation. */
export const redis = new Redis(config.REDIS_URL, {
  maxRetriesPerRequest: 2,
  enableAutoPipelining: true, // batches concurrent commands into one round trip
});
redis.on("error", (err) => logger.error({ err }, "redis error"));

/**
 * BullMQ needs its own connections with maxRetriesPerRequest = null, because
 * its blocking commands must wait indefinitely.
 */
export function queueConnection(): Redis {
  const conn = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });
  conn.on("error", (err) => logger.error({ err }, "redis (queue) error"));
  return conn;
}
