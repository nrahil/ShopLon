import Stripe from "stripe";
import { config } from "../../config.js";
import type { CreatedPayment, CreatePaymentInput, PaymentProvider, ProviderEvent, ProviderStatus } from "./provider.js";
import { WebhookSignatureError } from "./provider.js";

interface SessionLike {
  id: string;
  url?: string | null;
  status?: string | null;
  payment_status?: string;
  amount_total?: number | null;
  currency?: string | null;
  payment_intent?: string | { id: string } | null;
}

/**
 * Stripe Checkout (hosted payment page) in test mode. Enabled with
 * PAYMENT_PROVIDER=stripe plus STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET.
 * The shopper pays on stripe.com, and the result arrives by signed webhook.
 */
export class StripeProvider implements PaymentProvider {
  readonly name = "stripe" as const;
  private readonly stripe = new Stripe(config.STRIPE_SECRET_KEY!);

  async createPayment(input: CreatePaymentInput): Promise<CreatedPayment> {
    const session = (await this.stripe.checkout.sessions.create(
      {
        mode: "payment",
        line_items: [
          {
            quantity: 1,
            price_data: {
              currency: input.currency,
              unit_amount: input.amountCents,
              product_data: { name: `ShopLon order ${input.orderId.slice(0, 8).toUpperCase()}` },
            },
          },
        ],
        client_reference_id: input.orderId,
        metadata: { orderId: input.orderId, paymentId: input.paymentId },
        success_url: `${config.PUBLIC_API_URL}/v1/payments/return?status=success`,
        cancel_url: `${config.PUBLIC_API_URL}/v1/payments/return?status=cancelled`,
      },
      { idempotencyKey: `checkout_${input.paymentId}` },
    )) as unknown as SessionLike;
    return { providerRef: session.id, clientSecret: null, redirectUrl: session.url ?? null };
  }

  parseWebhook(rawBody: Buffer, headers: Record<string, string | string[] | undefined>): ProviderEvent {
    const sig = headers["stripe-signature"];
    let event: { id: string; type: string; data: { object: unknown } };
    try {
      event = this.stripe.webhooks.constructEvent(
        rawBody,
        Array.isArray(sig) ? sig[0]! : (sig ?? ""),
        config.STRIPE_WEBHOOK_SECRET!,
      ) as unknown as typeof event;
    } catch {
      throw new WebhookSignatureError("bad stripe signature");
    }
    const s = event.data.object as SessionLike;
    const base = { eventId: event.id, providerRef: s.id, amountCents: s.amount_total ?? 0, currency: s.currency ?? "" };
    switch (event.type) {
      case "checkout.session.completed":
      case "checkout.session.async_payment_succeeded":
        // "completed" can arrive before funds settle for delayed methods.
        return s.payment_status === "paid"
          ? { kind: "succeeded", ...base }
          : { kind: "ignored", eventId: event.id, type: event.type };
      case "checkout.session.async_payment_failed":
      case "checkout.session.expired":
        return { kind: "failed", ...base, failureReason: event.type.split(".").pop() };
      default:
        return { kind: "ignored", eventId: event.id, type: event.type };
    }
  }

  async retrieve(providerRef: string): Promise<ProviderStatus> {
    const s = (await this.stripe.checkout.sessions.retrieve(providerRef)) as unknown as SessionLike;
    return {
      status: s.payment_status === "paid" ? "succeeded" : s.status === "expired" ? "failed" : "pending",
      amountCents: s.amount_total ?? 0,
      currency: s.currency ?? "",
    };
  }

  async refund(providerRef: string, amountCents: number, idempotencyKey: string): Promise<void> {
    const s = (await this.stripe.checkout.sessions.retrieve(providerRef)) as unknown as SessionLike;
    const pi = typeof s.payment_intent === "string" ? s.payment_intent : s.payment_intent?.id;
    if (!pi) throw new Error(`session ${providerRef} has no payment intent to refund`);
    await this.stripe.refunds.create({ payment_intent: pi, amount: amountCents }, { idempotencyKey });
  }
}
