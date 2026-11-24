import type { FastifyPluginAsync } from "fastify";
import { requireUser } from "../app.js";
import { revokeSessions } from "../../auth/tokens.js";

export const authRoutes: FastifyPluginAsync = async (app) => {
  /** Confirms the session is valid server-side (used on app start). */
  app.get("/auth/session", { config: { auth: true } }, async (req) => {
    const user = requireUser(req);
    return { uid: user.uid, email: user.email ?? null };
  });

  /**
   * Server-side logout. Signing out in the Firebase SDK only forgets the token
   * on that device; a copied token would stay valid for up to an hour.
   * This rejects every token issued before now, on all devices.
   */
  app.post("/auth/logout", { config: { auth: true } }, async (req, reply) => {
    await revokeSessions(requireUser(req).uid);
    return reply.status(204).send();
  });
};
