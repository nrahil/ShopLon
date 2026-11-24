import type { FastifyPluginAsync, FastifyReply } from "fastify";
import { z } from "zod";
import { requireUser } from "../app.js";
import { withIdempotency, type IdempotentResponse } from "../idempotency.js";
import { logger } from "../../lib/logger.js";
import { cancelOrder, createOrderFromCart, getOrder, listOrders } from "../../modules/orders/orders.service.js";
import { startPayment } from "../../modules/payments/payments.service.js";

const orderParams = z.object({ id: z.string().uuid() });
const listQuery = z.object({
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
const strictLimit = { rateLimit: { max: 10, timeWindow: "1 minute" } };

function send(reply: FastifyReply, res: IdempotentResponse) {
  if (res.replayed) reply.header("idempotent-replayed", "true");
  return reply.status(res.status).send(res.body);
}

export const orderRoutes: FastifyPluginAsync = async (app) => {
  /**
   * Cart -> order (stock reserved) -> payment attempt.
   * Requires an Idempotency-Key, so a retried or double-tapped checkout
   * creates exactly one order.
   */
  app.post("/checkout", { config: { auth: true, ...strictLimit } }, async (req, reply) => {
    const { uid } = requireUser(req);
    const res = await withIdempotency(uid, req.headers["idempotency-key"] as string | undefined, "POST /checkout", {}, async () => {
      const order = await createOrderFromCart(uid);
      try {
        return { status: 201, body: await startPayment(uid, order.id) };
      } catch (err) {
        // The order and its reservation are safe. The client can start payment
        // again with POST /orders/:id/payments.
        logger.warn({ err, orderId: order.id }, "payment start failed after checkout");
        return { status: 201, body: await getOrder(uid, order.id) };
      }
    });
    return send(reply, res);
  });

  app.get("/orders", { config: { auth: true } }, async (req) => listOrders(requireUser(req).uid, listQuery.parse(req.query)));

  app.get("/orders/:id", { config: { auth: true } }, async (req) => {
    const { id } = orderParams.parse(req.params);
    return getOrder(requireUser(req).uid, id);
  });

  app.post("/orders/:id/payments", { config: { auth: true, ...strictLimit } }, async (req, reply) => {
    const { uid } = requireUser(req);
    const { id } = orderParams.parse(req.params);
    const res = await withIdempotency(uid, req.headers["idempotency-key"] as string | undefined, `POST /orders/${id}/payments`, {}, async () => ({
      status: 200,
      body: await startPayment(uid, id),
    }));
    return send(reply, res);
  });

  app.post("/orders/:id/cancel", { config: { auth: true, ...strictLimit } }, async (req) => {
    const { id } = orderParams.parse(req.params);
    return cancelOrder(requireUser(req).uid, id);
  });
};
