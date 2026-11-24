import type { FastifyPluginAsync } from "fastify";
import { logger } from "../../lib/logger.js";
import { paymentProvider, handleProviderEvent } from "../../modules/payments/payments.service.js";
import { WebhookSignatureError } from "../../modules/payments/provider.js";

export const webhookRoutes: FastifyPluginAsync = async (app) => {
  // Signatures are computed over the exact bytes sent, so this plugin keeps the
  // raw body instead of parsing JSON. (Scoped: other routes still get JSON.)
  app.removeContentTypeParser("application/json");
  app.addContentTypeParser("application/json", { parseAs: "buffer" }, (_req, body, done) => done(null, body));

  app.post(
    "/webhooks/:provider",
    // The PSP retries on failure, and per-IP limits would hit its shared egress IPs.
    { config: { rateLimit: false } },
    async (req, reply) => {
      const { provider } = req.params as { provider: string };
      const psp = paymentProvider();
      if (provider !== psp.name) return reply.status(404).send();

      let event;
      try {
        event = psp.parseWebhook(req.body as Buffer, req.headers);
      } catch (err) {
        if (err instanceof WebhookSignatureError) {
          logger.warn({ ip: req.ip }, "rejected webhook with invalid signature");
          return reply.status(400).send({ error: { code: "BAD_SIGNATURE", message: "Invalid signature" } });
        }
        throw err;
      }
      // Errors propagate as 500, so the PSP retries later. Success, duplicates
      // and unknown events are all acknowledged with 200 so it stops retrying.
      const result = await handleProviderEvent(event, "webhook");
      return { received: true, result };
    },
  );

  /** Landing page after Stripe's hosted checkout. The app polls the order itself. */
  app.get("/payments/return", async (req, reply) => {
    const ok = (req.query as { status?: string }).status === "success";
    return reply
      .type("text/html")
      .send(
        `<!doctype html><meta name="viewport" content="width=device-width"><title>ShopLon</title>` +
          `<body style="font-family:system-ui;text-align:center;padding:48px">` +
          `<h2>${ok ? "Payment received" : "Payment cancelled"}</h2><p>You can close this tab and return to ShopLon.</p></body>`,
      );
  });
};
