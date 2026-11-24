/**
 * Order lifecycle. Every status change goes through `assertTransition`, and
 * the SQL that applies it also checks the current status (compare-and-set),
 * so two racing actors (a late webhook and the expiry sweeper, say) can't
 * both win.
 *
 *   PENDING_PAYMENT ──pay──▶ PAID ──ship──▶ SHIPPED
 *        │  │                  │
 *        │  └─cancel─▶ CANCELLED ──late payment──▶ REFUND_PENDING ──▶ REFUNDED
 *        └──expire──▶ EXPIRED ──late payment, stock still there──▶ PAID
 *                         └────late payment, sold out──▶ REFUND_PENDING
 *   PAID ──duplicate/mismatched payment or refund──▶ REFUND_PENDING
 */
export const ORDER_STATUSES = [
  "PENDING_PAYMENT",
  "PAID",
  "SHIPPED",
  "CANCELLED",
  "EXPIRED",
  "REFUND_PENDING",
  "REFUNDED",
] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];

const TRANSITIONS: Record<OrderStatus, readonly OrderStatus[]> = {
  PENDING_PAYMENT: ["PAID", "CANCELLED", "EXPIRED"],
  PAID: ["SHIPPED", "REFUND_PENDING"],
  SHIPPED: [],
  CANCELLED: ["REFUND_PENDING"],
  EXPIRED: ["PAID", "REFUND_PENDING"],
  REFUND_PENDING: ["REFUNDED"],
  REFUNDED: [],
};

export function canTransition(from: OrderStatus, to: OrderStatus): boolean {
  return TRANSITIONS[from].includes(to);
}

export class InvalidTransitionError extends Error {
  constructor(
    readonly from: OrderStatus,
    readonly to: OrderStatus,
  ) {
    super(`Illegal order transition ${from} -> ${to}`);
  }
}

export function assertTransition(from: OrderStatus, to: OrderStatus): void {
  if (!canTransition(from, to)) throw new InvalidTransitionError(from, to);
}

/** Statuses from which `to` is reachable. Used in `WHERE status = ANY(...)` guards. */
export function sourcesOf(to: OrderStatus): OrderStatus[] {
  return ORDER_STATUSES.filter((s) => TRANSITIONS[s].includes(to));
}
