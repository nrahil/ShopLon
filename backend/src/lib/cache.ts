import { redis } from "./redis.js";
import { logger } from "./logger.js";
import { cacheEvents } from "./metrics.js";

/**
 * Cache-aside read with two stampede defences:
 *  1. Single-flight: concurrent misses for the same key in this process share
 *     one loader call instead of each hitting Postgres.
 *  2. TTL jitter: keys written together don't all expire at the same instant.
 * If Redis is down, it degrades to calling the loader directly.
 */
const inFlight = new Map<string, Promise<unknown>>();

export async function cached<T>(key: string, ttlSeconds: number, loader: () => Promise<T>): Promise<T> {
  try {
    const hit = await redis.get(key);
    if (hit !== null) {
      cacheEvents.inc({ result: "hit" });
      return JSON.parse(hit) as T;
    }
  } catch (err) {
    logger.warn({ err, key }, "cache read failed; falling back to source");
  }
  cacheEvents.inc({ result: "miss" });

  const existing = inFlight.get(key) as Promise<T> | undefined;
  if (existing) return existing;

  const load = (async () => {
    try {
      const value = await loader();
      const ttl = ttlSeconds + Math.floor(Math.random() * Math.max(1, ttlSeconds * 0.2));
      redis.set(key, JSON.stringify(value), "EX", ttl).catch((err) => logger.warn({ err, key }, "cache write failed"));
      return value;
    } finally {
      inFlight.delete(key);
    }
  })();
  inFlight.set(key, load);
  return load;
}

/** Bumping the namespace version makes every older cache key unreachable at once. */
export async function cacheNamespace(name: string): Promise<string> {
  const v = (await redis.get(`cache:ns:${name}`).catch(() => null)) ?? "0";
  return `${name}:v${v}`;
}

export async function invalidateNamespace(name: string): Promise<void> {
  await redis.incr(`cache:ns:${name}`);
}
