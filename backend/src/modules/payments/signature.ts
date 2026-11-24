import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Stripe-style webhook signatures: header `t=<unix seconds>,v1=<hex HMAC-SHA256>`,
 * where the HMAC covers `${t}.${rawBody}`.
 *  - Signing the raw bytes means re-serialised JSON can't be forged.
 *  - Including the timestamp and enforcing a tolerance blocks replays of old,
 *    captured requests.
 *  - A constant-time comparison avoids leaking the signature through timing.
 */
export const SIGNATURE_TOLERANCE_SECONDS = 300;

export function sign(secret: string, rawBody: string | Buffer, timestamp = Math.floor(Date.now() / 1000)): string {
  const mac = createHmac("sha256", secret).update(`${timestamp}.`).update(rawBody).digest("hex");
  return `t=${timestamp},v1=${mac}`;
}

export function verify(
  secret: string,
  rawBody: Buffer,
  header: string | undefined,
  now = Math.floor(Date.now() / 1000),
): boolean {
  if (!header) return false;
  const parts = Object.fromEntries(
    header.split(",").map((kv) => {
      const i = kv.indexOf("=");
      return [kv.slice(0, i).trim(), kv.slice(i + 1).trim()];
    }),
  );
  const t = Number(parts.t);
  const v1 = parts.v1;
  if (!Number.isInteger(t) || !v1 || !/^[0-9a-f]{64}$/.test(v1)) return false;
  if (Math.abs(now - t) > SIGNATURE_TOLERANCE_SECONDS) return false;

  const expected = createHmac("sha256", secret).update(`${t}.`).update(rawBody).digest();
  const given = Buffer.from(v1, "hex");
  return given.length === expected.length && timingSafeEqual(given, expected);
}
