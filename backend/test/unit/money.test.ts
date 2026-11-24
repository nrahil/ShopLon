import { describe, expect, it } from "vitest";
import { computeTotals, discounted, toCents } from "../../src/lib/money.js";

describe("money", () => {
  it("converts dollars to integer cents without float drift", () => {
    expect(toCents(9.99)).toBe(999);
    expect(toCents(0.1 + 0.2)).toBe(30);
  });

  it("rounds discounts to the nearest cent", () => {
    expect(discounted(999, 10)).toBe(899); // 899.1
    expect(discounted(1000, 0)).toBe(1000);
  });

  it("charges flat shipping under the threshold and none above it", () => {
    expect(computeTotals([{ unitPriceCents: 5000, quantity: 1 }])).toEqual({
      subtotalCents: 5000,
      shippingCents: 1000,
      taxCents: 400,
      totalCents: 6400,
    });
    expect(computeTotals([{ unitPriceCents: 5000, quantity: 2 }]).shippingCents).toBe(0);
  });

  it("returns zeroes for an empty cart", () => {
    expect(computeTotals([]).totalCents).toBe(0);
  });
});
