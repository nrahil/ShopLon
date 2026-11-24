import { describe, expect, it } from "vitest";
import { assertTransition, canTransition, InvalidTransitionError, sourcesOf } from "../../src/modules/orders/order-state.js";

describe("order state machine", () => {
  it("allows the happy path", () => {
    expect(canTransition("PENDING_PAYMENT", "PAID")).toBe(true);
    expect(canTransition("PAID", "SHIPPED")).toBe(true);
  });

  it("never un-ships or re-opens a finished order", () => {
    expect(canTransition("SHIPPED", "PAID")).toBe(false);
    expect(canTransition("REFUNDED", "PAID")).toBe(false);
    expect(canTransition("PAID", "PENDING_PAYMENT")).toBe(false);
    expect(() => assertTransition("CANCELLED", "PAID")).toThrow(InvalidTransitionError);
  });

  it("lets a late payment revive an expired order but not a cancelled one", () => {
    expect(canTransition("EXPIRED", "PAID")).toBe(true);
    expect(canTransition("CANCELLED", "PAID")).toBe(false);
    expect(canTransition("CANCELLED", "REFUND_PENDING")).toBe(true);
  });

  it("only pending orders can be cancelled", () => {
    expect(sourcesOf("CANCELLED")).toEqual(["PENDING_PAYMENT"]);
  });
});
