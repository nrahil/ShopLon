import { z } from "zod";

/**
 * All configuration comes from environment variables and is validated once at
 * start-up. A bad value fails fast with a readable error, rather than surfacing
 * later as a confusing runtime bug.
 */
const bool = z
  .enum(["true", "false", "1", "0"])
  .transform((v) => v === "true" || v === "1");

const schema = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().int().positive().default(3000),
    LOG_LEVEL: z.string().default("info"),

    DATABASE_URL: z.string().url(),
    DATABASE_POOL_MAX: z.coerce.number().int().positive().default(20),
    REDIS_URL: z.string().url(),

    /** Firebase project whose ID tokens we accept. */
    FIREBASE_PROJECT_ID: z.string().min(1),
    /**
     * Accept HS256 tokens signed with AUTH_DEV_SECRET (used by tests and the
     * load-test script). Refused in production; see the refinement below.
     */
    AUTH_ALLOW_DEV_TOKENS: bool.default(false),
    AUTH_DEV_SECRET: z.string().optional(),

    /** Comma-separated list of browser origins allowed to call the API. */
    CORS_ORIGINS: z.string().default("http://localhost:5000"),
    /** Trust X-Forwarded-For from the load balancer (needed for per-IP rate limits). */
    TRUST_PROXY: bool.default(false),

    PAYMENT_PROVIDER: z.enum(["mock", "stripe"]).default("mock"),
    MOCK_PSP_URL: z.string().url().default("http://localhost:8090"),
    /** URL the *browser* uses to reach the mock PSP (differs from MOCK_PSP_URL inside Docker). */
    MOCK_PSP_PUBLIC_URL: z.string().url().default("http://localhost:8090"),
    MOCK_PSP_SECRET_KEY: z.string().default("sk_mock_local"),
    MOCK_PSP_WEBHOOK_SECRET: z.string().default("whsec_mock_local"),
    STRIPE_SECRET_KEY: z.string().optional(),
    STRIPE_WEBHOOK_SECRET: z.string().optional(),
    /** Public base URL of this API (Stripe redirects the shopper back here). */
    PUBLIC_API_URL: z.string().url().default("http://localhost:8080"),

    /** How long checkout holds stock before an unpaid order expires. */
    RESERVATION_TTL_SECONDS: z.coerce.number().int().positive().default(15 * 60),
    CURRENCY: z.string().length(3).default("usd"),
  })
  .superRefine((c, ctx) => {
    if (c.NODE_ENV === "production" && c.AUTH_ALLOW_DEV_TOKENS) {
      ctx.addIssue({ code: "custom", message: "AUTH_ALLOW_DEV_TOKENS must be false in production" });
    }
    if (c.AUTH_ALLOW_DEV_TOKENS && (!c.AUTH_DEV_SECRET || c.AUTH_DEV_SECRET.length < 32)) {
      ctx.addIssue({ code: "custom", message: "AUTH_DEV_SECRET (>= 32 chars) is required when dev tokens are enabled" });
    }
    if (c.PAYMENT_PROVIDER === "stripe" && (!c.STRIPE_SECRET_KEY || !c.STRIPE_WEBHOOK_SECRET)) {
      ctx.addIssue({ code: "custom", message: "STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET are required for PAYMENT_PROVIDER=stripe" });
    }
    if (c.NODE_ENV === "production" && c.PAYMENT_PROVIDER === "mock" && c.MOCK_PSP_WEBHOOK_SECRET === "whsec_mock_local") {
      ctx.addIssue({ code: "custom", message: "Set a real MOCK_PSP_WEBHOOK_SECRET in production" });
    }
  });

export type Config = z.infer<typeof schema>;

function load(): Config {
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    const lines = parsed.error.issues.map((i) => `  - ${i.path.join(".") || "config"}: ${i.message}`);
    // eslint-disable-next-line no-console
    console.error(`Invalid configuration:\n${lines.join("\n")}`);
    process.exit(1);
  }
  return parsed.data;
}

export const config = load();
export const corsOrigins = config.CORS_ORIGINS.split(",").map((s) => s.trim()).filter(Boolean);
