import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { requireUser } from "../app.js";
import { addItem, getCart, setQuantity } from "../../modules/cart/cart.service.js";
import { MAX_QTY_PER_LINE } from "../../modules/cart/cart.store.js";

const option = z
  .string()
  .trim()
  .max(32)
  .regex(/^[^|]*$/, "must not contain |")
  .nullish()
  .transform((v) => v || null);

const addBody = z.object({
  productId: z.string().regex(/^[\w-]{1,64}$/),
  quantity: z.number().int().min(1).max(MAX_QTY_PER_LINE).default(1),
  size: option,
  color: option,
});
const lineParams = z.object({ lineKey: z.string().min(1).max(200) });
const setBody = z.object({ quantity: z.number().int().min(0).max(MAX_QTY_PER_LINE) });

const writeLimit = { rateLimit: { max: 120, timeWindow: "1 minute" } };

export const cartRoutes: FastifyPluginAsync = async (app) => {
  app.get("/cart", { config: { auth: true } }, async (req) => getCart(requireUser(req).uid));

  app.post("/cart/items", { config: { auth: true, ...writeLimit } }, async (req) =>
    addItem(requireUser(req).uid, addBody.parse(req.body)),
  );

  // PUT sets an absolute quantity, so retrying it is naturally idempotent.
  app.put("/cart/items/:lineKey", { config: { auth: true, ...writeLimit } }, async (req) => {
    const { lineKey } = lineParams.parse(req.params);
    return setQuantity(requireUser(req).uid, lineKey, setBody.parse(req.body).quantity);
  });

  app.delete("/cart/items/:lineKey", { config: { auth: true, ...writeLimit } }, async (req) => {
    const { lineKey } = lineParams.parse(req.params);
    return setQuantity(requireUser(req).uid, lineKey, 0);
  });
};
