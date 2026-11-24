/**
 * Money is always an integer number of cents. Floating-point dollars are only
 * used at the edges (display, third-party catalogue import).
 */
export const FREE_SHIPPING_THRESHOLD_CENTS = 100_00;
export const FLAT_SHIPPING_CENTS = 10_00;
export const TAX_RATE_BASIS_POINTS = 800; // 8.00%

export function toCents(dollars: number): number {
  return Math.round(dollars * 100);
}

/** Applies a percentage discount and rounds to the nearest cent. */
export function discounted(priceCents: number, discountPercent: number): number {
  if (discountPercent <= 0) return priceCents;
  return Math.round((priceCents * (100 - discountPercent)) / 100);
}

export interface Totals {
  subtotalCents: number;
  shippingCents: number;
  taxCents: number;
  totalCents: number;
}

export function computeTotals(lines: { unitPriceCents: number; quantity: number }[]): Totals {
  const subtotalCents = lines.reduce((sum, l) => sum + l.unitPriceCents * l.quantity, 0);
  const shippingCents =
    subtotalCents === 0 || subtotalCents >= FREE_SHIPPING_THRESHOLD_CENTS ? 0 : FLAT_SHIPPING_CENTS;
  const taxCents = Math.round((subtotalCents * TAX_RATE_BASIS_POINTS) / 10_000);
  return { subtotalCents, shippingCents, taxCents, totalCents: subtotalCents + shippingCents + taxCents };
}
