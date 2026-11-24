import Fastify, { type FastifyRequest } from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import { randomUUID } from "node:crypto";
import { ZodError } from "zod";
import { config, corsOrigins } from "../config.js";
import { AppError } from "../lib/errors.js";
import { logger } from "../lib/logger.js";
import { redis } from "../lib/redis.js";
import { httpDuration } from "../lib/metrics.js";
import { authenticate, type AuthUser } from "../auth/tokens.js";
import { catalogRoutes } from "./routes/catalog.js";
import { cartRoutes } from "./routes/cart.js";
import { orderRoutes } from "./routes/orders.js";
import { authRoutes } from "./routes/auth.js";
import { webhookRoutes } from "./routes/webhooks.js";
import { opsRoutes } from "./routes/ops.js";

declare module "fastify" {
  interface FastifyRequest {
    user?: AuthUser;
  }
  interface FastifyContextConfig {
    /** Route requires a verified Firebase session. */
    auth?: boolean;
  }
}

export function requireUser(req: FastifyRequest): AuthUser {
  if (!req.user) throw new AppError(401, "UNAUTHENTICATED", "Authentication required");
  return req.user;
}

export async function buildApp() {
  const app = Fastify({
    loggerInstance: logger,
    trustProxy: config.TRUST_PROXY,
    bodyLimit: 64 * 1024, // nothing legitimate is bigger. Blunts payload-size DoS.
    genReqId: (req) => {
      const incoming = req.headers["x-request-id"];
      return typeof incoming === "string" && /^[\w-]{8,64}$/.test(incoming) ? incoming : randomUUID();
    },
    routerOptions: { maxParamLength: 200 },
  });

  await app.register(helmet, { contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: "cross-origin" } });
  await app.register(cors, {
    origin: (origin, cb) => cb(null, !origin || corsOrigins.includes(origin)),
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["authorization", "content-type", "idempotency-key", "x-request-id", "if-none-match"],
    exposedHeaders: ["x-request-id", "idempotent-replayed", "retry-after", "etag"],
    maxAge: 600,
  });

  // Treat an empty JSON body as {} (some clients always send the header), but
  // keep Fastify's parser, which rejects __proto__/constructor poisoning.
  const jsonParser = app.getDefaultJsonParser("error", "error");
  app.removeContentTypeParser("application/json");
  app.addContentTypeParser("application/json", { parseAs: "string" }, (req, body, done) => {
    if (body === "") return done(null, {});
    jsonParser(req, body as string, done);
  });

  // Authentication runs before rate limiting, so limits are per user
  // (fair, NAT-friendly) and only fall back to per-IP for anonymous traffic.
  app.addHook("onRequest", async (req) => {
    if (req.routeOptions.config.auth) req.user = await authenticate(req.headers.authorization);
  });

  await app.register(rateLimit, {
    global: true,
    hook: "preHandler",
    max: 300,
    timeWindow: "1 minute",
    redis, // shared counters: the limit holds across all API replicas
    nameSpace: "rl:",
    keyGenerator: (req) => (req.user ? `u:${req.user.uid}` : `ip:${req.ip}`),
    skipOnError: true, // if Redis is down, serve traffic rather than fail closed
    allowList: (req) => req.url.startsWith("/healthz") || req.url.startsWith("/readyz"),
    errorResponseBuilder: (_req, ctx) => ({
      statusCode: 429,
      error: { code: "RATE_LIMITED", message: `Too many requests. Try again in ${Math.ceil(ctx.ttl / 1000)}s.` },
    }),
  });

  app.addHook("onSend", async (req, reply) => {
    reply.header("x-request-id", req.id);
  });
  app.addHook("onResponse", async (req, reply) => {
    httpDuration.observe(
      { method: req.method, route: req.routeOptions.url ?? "unmatched", status: String(reply.statusCode) },
      reply.elapsedTime / 1000,
    );
  });

  app.setErrorHandler((err, req, reply) => {
    if (err instanceof AppError) {
      if (err.code === "REQUEST_IN_PROGRESS") reply.header("retry-after", "1");
      return reply.status(err.status).send({ error: { code: err.code, message: err.message, details: err.details } });
    }
    if (err instanceof ZodError) {
      return reply.status(400).send({
        error: {
          code: "VALIDATION_FAILED",
          message: "Invalid request",
          details: { issues: err.issues.map((i) => ({ path: i.path.join("."), message: i.message })) },
        },
      });
    }
    const e = err as Error & { statusCode?: number; code?: string };
    if (e.statusCode && e.statusCode < 500) {
      return reply.status(e.statusCode).send({ error: { code: e.code ?? "BAD_REQUEST", message: e.message } });
    }
    req.log.error({ err }, "unhandled error");
    return reply.status(500).send({ error: { code: "INTERNAL", message: "Something went wrong", requestId: req.id } });
  });

  app.setNotFoundHandler((_req, reply) => reply.status(404).send({ error: { code: "NOT_FOUND", message: "Route not found" } }));

  await app.register(opsRoutes);
  await app.register(webhookRoutes, { prefix: "/v1" });
  await app.register(catalogRoutes, { prefix: "/v1" });
  await app.register(authRoutes, { prefix: "/v1" });
  await app.register(cartRoutes, { prefix: "/v1" });
  await app.register(orderRoutes, { prefix: "/v1" });
  return app;
}
