import { createHash } from "node:crypto";
import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from "fastify";
import { z } from "zod";
import { notFound } from "../../lib/errors.js";
import { getProduct, listCategories, listProducts } from "../../modules/catalog/catalog.service.js";

/**
 * Public, cacheable catalogue. Responses carry an ETag, and a client or CDN
 * holding the latest version gets a body-less 304.
 */
function sendCacheable(req: FastifyRequest, reply: FastifyReply, body: unknown, maxAge: number) {
  const json = JSON.stringify(body);
  const etag = `"${createHash("sha1").update(json).digest("base64url")}"`;
  reply.header("etag", etag).header("cache-control", `public, max-age=${maxAge}, stale-while-revalidate=60`);
  if (req.headers["if-none-match"] === etag) return reply.status(304).send();
  return reply.type("application/json").send(json);
}

const listQuery = z.object({
  category: z.string().regex(/^[a-z0-9-]{1,64}$/).optional(),
  cursor: z.string().max(64).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

export const catalogRoutes: FastifyPluginAsync = async (app) => {
  app.get("/products", async (req, reply) => {
    const q = listQuery.parse(req.query);
    return sendCacheable(req, reply, await listProducts(q), 30);
  });

  app.get("/products/:id", async (req, reply) => {
    const { id } = z.object({ id: z.string().regex(/^[\w-]{1,64}$/) }).parse(req.params);
    const product = await getProduct(id);
    if (!product) throw notFound("Product");
    return sendCacheable(req, reply, product, 15);
  });

  app.get("/categories", async (req, reply) => sendCacheable(req, reply, { items: await listCategories() }, 300));
};
