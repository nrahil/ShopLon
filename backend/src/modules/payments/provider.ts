/**
 * Payment providers sit behind one small interface, so business logic never
 * depends on a specific PSP. Card data never reaches our servers: the browser
 * sends it straight to the provider (the PCI-DSS SAQ-A model).
 */
export interface CreatePaymentInput {
  paymentId: string;
  orderId: string;
  amountCents: number;
  currency: string;
}

export interface CreatedPayment {
  providerRef: string;
  clientSecret: string | null;
  redirectUrl: string | null;
}

export type ProviderEvent =
  | {
      kind: "succeeded" | "failed";
      eventId: string;
      providerRef: string;
      amountCents: number;
      currency: string;
      failureReason?: string;
    }
  | { kind: "ignored"; eventId: string; type: string };

export interface ProviderStatus {
  status: "pending" | "succeeded" | "failed";
  amountCents: number;
  currency: string;
  failureReason?: string;
}

export interface PaymentProvider {
  readonly name: "mock" | "stripe";
  /** Must be idempotent on paymentId: a retry returns the same provider object. */
  createPayment(input: CreatePaymentInput): Promise<CreatedPayment>;
  /** Verifies the signature (throws if invalid) and normalises the event. */
  parseWebhook(rawBody: Buffer, headers: Record<string, string | string[] | undefined>): ProviderEvent;
  /** Polled by reconciliation when a webhook may have been lost. */
  retrieve(providerRef: string): Promise<ProviderStatus>;
  refund(providerRef: string, amountCents: number, idempotencyKey: string): Promise<void>;
}

export class WebhookSignatureError extends Error {}
