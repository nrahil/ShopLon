import { config } from "../../config.js";
import type { CreatedPayment, CreatePaymentInput, PaymentProvider, ProviderEvent, ProviderStatus } from "./provider.js";
import { WebhookSignatureError } from "./provider.js";
import { verify } from "./signature.js";

interface MockIntent {
  id: string;
  client_secret: string;
  status: "requires_payment_method" | "processing" | "succeeded" | "failed";
  amount: number;
  currency: string;
  failure_code?: string;
}

/** Adapter for the bundled mock PSP (src/mock-psp), which follows Stripe's API shape. */
export class MockProvider implements PaymentProvider {
  readonly name = "mock" as const;

  private async call<T>(method: string, path: string, body?: unknown, idempotencyKey?: string): Promise<T> {
    const res = await fetch(`${config.MOCK_PSP_URL}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${config.MOCK_PSP_SECRET_KEY}`,
        "content-type": "application/json",
        ...(idempotencyKey ? { "idempotency-key": idempotencyKey } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) throw new Error(`mock PSP ${method} ${path} -> ${res.status}`);
    return (await res.json()) as T;
  }

  async createPayment(input: CreatePaymentInput): Promise<CreatedPayment> {
    const intent = await this.call<MockIntent>(
      "POST",
      "/v1/payment_intents",
      { amount: input.amountCents, currency: input.currency, metadata: { orderId: input.orderId, paymentId: input.paymentId } },
      input.paymentId,
    );
    return { providerRef: intent.id, clientSecret: intent.client_secret, redirectUrl: null };
  }

  parseWebhook(rawBody: Buffer, headers: Record<string, string | string[] | undefined>): ProviderEvent {
    const header = headers["mock-signature"];
    if (!verify(config.MOCK_PSP_WEBHOOK_SECRET, rawBody, Array.isArray(header) ? header[0] : header)) {
      throw new WebhookSignatureError("bad mock signature");
    }
    const event = JSON.parse(rawBody.toString("utf8")) as { id: string; type: string; data: MockIntent };
    if (event.type === "payment_intent.succeeded" || event.type === "payment_intent.payment_failed") {
      return {
        kind: event.type === "payment_intent.succeeded" ? "succeeded" : "failed",
        eventId: event.id,
        providerRef: event.data.id,
        amountCents: event.data.amount,
        currency: event.data.currency,
        failureReason: event.data.failure_code,
      };
    }
    return { kind: "ignored", eventId: event.id, type: event.type };
  }

  async retrieve(providerRef: string): Promise<ProviderStatus> {
    const intent = await this.call<MockIntent>("GET", `/v1/payment_intents/${encodeURIComponent(providerRef)}`);
    return {
      status: intent.status === "succeeded" ? "succeeded" : intent.status === "failed" ? "failed" : "pending",
      amountCents: intent.amount,
      currency: intent.currency,
      failureReason: intent.failure_code,
    };
  }

  async refund(providerRef: string, amountCents: number, idempotencyKey: string): Promise<void> {
    await this.call("POST", "/v1/refunds", { payment_intent: providerRef, amount: amountCents }, idempotencyKey);
  }
}
