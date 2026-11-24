import { createRemoteJWKSet, jwtVerify, type JWTPayload } from "jose";
import { config } from "../config.js";
import { redis } from "../lib/redis.js";
import { pool } from "../db/pool.js";
import { unauthorized } from "../lib/errors.js";
import { DEV_AUDIENCE, DEV_ISSUER } from "./dev-token.js";

export interface AuthUser {
  uid: string;
  email?: string;
  /** Seconds since epoch when this token was issued. */
  issuedAt: number;
}

/**
 * Firebase ID tokens are RS256 JWTs signed by Google. We verify them locally
 * against Google's published keys (cached and refreshed by `jose`), so there's
 * no network call per request and no dependency on the Admin SDK.
 */
const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
  { cooldownDuration: 30_000, cacheMaxAge: 6 * 60 * 60 * 1000 },
);

const devKey = config.AUTH_DEV_SECRET ? new TextEncoder().encode(config.AUTH_DEV_SECRET) : null;

async function verifyJwt(token: string): Promise<JWTPayload> {
  if (config.AUTH_ALLOW_DEV_TOKENS && devKey) {
    // Peek at the issuer to choose the key. The signature is still fully verified.
    const [, body] = token.split(".");
    try {
      const iss = JSON.parse(Buffer.from(body ?? "", "base64url").toString()).iss;
      if (iss === DEV_ISSUER) {
        return (await jwtVerify(token, devKey, { issuer: DEV_ISSUER, audience: DEV_AUDIENCE, algorithms: ["HS256"] }))
          .payload;
      }
    } catch {
      /* fall through to Firebase verification */
    }
  }
  const { payload } = await jwtVerify(token, firebaseJwks, {
    issuer: `https://securetoken.google.com/${config.FIREBASE_PROJECT_ID}`,
    audience: config.FIREBASE_PROJECT_ID,
    algorithms: ["RS256"],
    clockTolerance: 5,
  });
  return payload;
}

const revokedKey = (uid: string) => `auth:revoked_before:${uid}`;

export async function authenticate(authorization: string | undefined): Promise<AuthUser> {
  const match = /^Bearer (.+)$/.exec(authorization ?? "");
  if (!match?.[1]) throw unauthorized();

  let payload: JWTPayload;
  try {
    payload = await verifyJwt(match[1]);
  } catch {
    throw unauthorized("Invalid or expired session. Please sign in again.");
  }
  const uid = payload.sub;
  if (!uid || uid.length > 128) throw unauthorized();
  const issuedAt = payload.iat ?? 0;

  // Server-side logout: tokens issued before the user's last logout are
  // rejected immediately, instead of staying valid until they expire (up to 1 h).
  const revokedBefore = Number(await redis.get(revokedKey(uid)));
  if (revokedBefore && issuedAt < revokedBefore) {
    throw unauthorized("Your session has ended. Please sign in again.");
  }

  const user: AuthUser = { uid, email: typeof payload.email === "string" ? payload.email : undefined, issuedAt };
  await ensureUserRow(user);
  return user;
}

/** Ends every session for this user that was issued before now. */
export async function revokeSessions(uid: string): Promise<void> {
  const now = Math.floor(Date.now() / 1000);
  // Firebase ID tokens live for at most an hour, so the marker can expire after that.
  await redis.set(revokedKey(uid), String(now), "EX", 2 * 60 * 60);
}

/** Upserts the user row at most once a day per user (memoised in Redis). */
async function ensureUserRow(user: AuthUser): Promise<void> {
  const fresh = await redis.set(`user:known:${user.uid}`, "1", "EX", 24 * 60 * 60, "NX");
  if (fresh !== "OK") return;
  await pool.query(
    `INSERT INTO users (id, email) VALUES ($1, $2)
     ON CONFLICT (id) DO UPDATE SET email = COALESCE(EXCLUDED.email, users.email), last_seen_at = now()`,
    [user.uid, user.email ?? null],
  );
}
