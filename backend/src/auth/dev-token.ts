import { SignJWT } from "jose";

export const DEV_ISSUER = "shoplon-dev";
export const DEV_AUDIENCE = "shoplon-api";

/**
 * Mints a short-lived HS256 token for tests and load tests. The API only
 * accepts these when AUTH_ALLOW_DEV_TOKENS=true, which config refuses in production.
 */
export async function mintDevToken(secret: string, uid: string, email = `${uid}@example.test`): Promise<string> {
  return new SignJWT({ email })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(uid)
    .setIssuer(DEV_ISSUER)
    .setAudience(DEV_AUDIENCE)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(new TextEncoder().encode(secret));
}
