import { createHash } from "node:crypto";
import { pool } from "../db/pool.js";
import { AppError, badRequest, conflict } from "../lib/errors.js";
import { idempotencyEvents } from "../lib/metrics.js";

/**
 * Idempotency keys make unsafe requests (checkout, pay) safe to retry.
 * A flaky network, a double tap or a client retry with the same
 * `Idempotency-Key` header produces exactly one order.
 *
 *  1. Claim the key with INSERT ... ON CONFLICT DO NOTHING. The primary key
 *     makes the claim atomic across every API replica.
 *  2. Winner: run the handler and store the response (2xx and 4xx; a 5xx
 *     releases the key so the client can retry).
 *  3. Losers: the same request that's finished replays the stored response.
 *     One still running gets 409 + Retry-After. The same key with a
 *     different body gets 422, because that's a client bug.
 *  4. A claim whose owner crashed is taken over after `locked_until`.
 * Keys are purged after 24 h by the worker.
 */
const LOCK_SECONDS = 30;
const KEY_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

export interface IdempotentResponse {
  status: number;
  body: unknown;
  replayed: boolean;
}

export async function withIdempotency(
  userId: string,
  key: string | undefined,
  route: string,
  requestBody: unknown,
  handler: () => Promise<{ status: number; body: unknown }>,
): Promise<IdempotentResponse> {
  if (!key || !KEY_PATTERN.test(key)) {
    throw badRequest("IDEMPOTENCY_KEY_REQUIRED", "An Idempotency-Key header (16-128 URL-safe characters) is required");
  }
  const requestHash = createHash("sha256")
    .update(route)
    .update(JSON.stringify(requestBody ?? null))
    .digest("hex");

  const claimed = await pool.query(
    `INSERT INTO idempotency_keys (user_id, key, route, request_hash, status, locked_until)
     VALUES ($1, $2, $3, $4, 'IN_PROGRESS', now() + make_interval(secs => $5))
     ON CONFLICT (user_id, key) DO NOTHING`,
    [userId, key, route, requestHash, LOCK_SECONDS],
  );

  if (claimed.rowCount === 0) {
    const { rows } = await pool.query<{
      request_hash: string;
      route: string;
      status: string;
      response_code: number | null;
      response_body: unknown;
      stale: boolean;
    }>(
      `SELECT request_hash, route, status, response_code, response_body, locked_until < now() AS stale
       FROM idempotency_keys WHERE user_id = $1 AND key = $2`,
      [userId, key],
    );
    const existing = rows[0];
    if (!existing) {
      // Purged between our insert and select. Ask the client to retry.
      throw conflict("REQUEST_IN_PROGRESS", "Please retry");
    }
    if (existing.request_hash !== requestHash || existing.route !== route) {
      idempotencyEvents.inc({ result: "mismatch" });
      throw new AppError(422, "IDEMPOTENCY_KEY_REUSED", "This Idempotency-Key was already used for a different request");
    }
    if (existing.status === "COMPLETED") {
      idempotencyEvents.inc({ result: "replayed" });
      return { status: existing.response_code ?? 200, body: existing.response_body, replayed: true };
    }
    // In progress. Take it over only if the original owner died.
    const takeover = await pool.query(
      `UPDATE idempotency_keys SET locked_until = now() + make_interval(secs => $3)
       WHERE user_id = $1 AND key = $2 AND status = 'IN_PROGRESS' AND locked_until < now()`,
      [userId, key, LOCK_SECONDS],
    );
    if (takeover.rowCount === 0) {
      idempotencyEvents.inc({ result: "in_progress" });
      throw new AppError(409, "REQUEST_IN_PROGRESS", "This request is still being processed", { retryAfterSeconds: 1 });
    }
  }

  idempotencyEvents.inc({ result: "executed" });
  let response: { status: number; body: unknown };
  try {
    response = await handler();
  } catch (err) {
    if (err instanceof AppError && err.status < 500) {
      response = { status: err.status, body: { error: { code: err.code, message: err.message, details: err.details } } };
    } else {
      await pool.query("DELETE FROM idempotency_keys WHERE user_id = $1 AND key = $2", [userId, key]);
      throw err;
    }
  }
  await pool.query(
    `UPDATE idempotency_keys SET status = 'COMPLETED', response_code = $3, response_body = $4
     WHERE user_id = $1 AND key = $2`,
    [userId, key, response.status, JSON.stringify(response.body)],
  );
  return { ...response, replayed: false };
}

export async function purgeIdempotencyKeys(): Promise<number> {
  const { rowCount } = await pool.query("DELETE FROM idempotency_keys WHERE created_at < now() - interval '24 hours'");
  return rowCount ?? 0;
}
