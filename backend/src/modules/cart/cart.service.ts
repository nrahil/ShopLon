import { badRequest, conflict, notFound } from "../../lib/errors.js";
import { computeTotals, type Totals } from "../../lib/money.js";
import { cartOps } from "../../lib/metrics.js";
import { getProduct, type ProductDto } from "../catalog/catalog.service.js";
import { MAX_LINES, mutateLine, readCart } from "./cart.store.js";

export interface CartLineDto {
  lineKey: string;
  product: ProductDto;
  quantity: number;
  selectedSize: string | null;
  selectedColor: string | null;
  lineTotalCents: number;
}

export interface CartDto {
  version: number;
  lines: CartLineDto[];
  totals: Totals;
}

/** A cart line is identified by product + chosen options. "|" is reserved as the separator. */
export function lineKeyOf(productId: string, size?: string | null, color?: string | null): string {
  return [productId, size ?? "", color ?? ""].join("|");
}

export function parseLineKey(lineKey: string): { productId: string; size: string | null; color: string | null } {
  const [productId = "", size = "", color = ""] = lineKey.split("|");
  return { productId, size: size || null, color: color || null };
}

export async function getCart(uid: string): Promise<CartDto> {
  const snapshot = await readCart(uid);
  const lines: CartLineDto[] = [];
  for (const [lineKey, quantity] of snapshot.lines) {
    const { productId, size, color } = parseLineKey(lineKey);
    const product = await getProduct(productId);
    if (!product) continue; // product was removed from the catalogue
    lines.push({
      lineKey,
      product,
      quantity,
      selectedSize: size,
      selectedColor: color,
      lineTotalCents: product.salePriceCents * quantity,
    });
  }
  lines.sort((a, b) => a.lineKey.localeCompare(b.lineKey));
  return {
    version: snapshot.version,
    lines,
    totals: computeTotals(lines.map((l) => ({ unitPriceCents: l.product.salePriceCents, quantity: l.quantity }))),
  };
}

async function requireProduct(productId: string): Promise<ProductDto> {
  const product = await getProduct(productId);
  if (!product) throw notFound("Product");
  if (product.stock <= 0) throw conflict("OUT_OF_STOCK", `${product.title} is out of stock`);
  return product;
}

export async function addItem(
  uid: string,
  input: { productId: string; quantity: number; size?: string | null; color?: string | null },
): Promise<CartDto> {
  const product = await requireProduct(input.productId);
  const res = await mutateLine(uid, lineKeyOf(input.productId, input.size, input.color), "incr", input.quantity, product.stock);
  cartOps.inc({ op: "add" });
  if (!res.ok) throw badRequest(res.reason, `Your cart can hold at most ${MAX_LINES} different items`);
  return getCart(uid);
}

export async function setQuantity(uid: string, lineKey: string, quantity: number): Promise<CartDto> {
  const { productId } = parseLineKey(lineKey);
  // Removing never needs a stock check. Changing a quantity re-validates the product.
  const max = quantity === 0 ? 0 : (await requireProduct(productId)).stock;
  const res = await mutateLine(uid, lineKey, "set", quantity, Math.max(max, 0));
  cartOps.inc({ op: quantity === 0 ? "remove" : "set" });
  if (!res.ok) throw badRequest(res.reason, `Your cart can hold at most ${MAX_LINES} different items`);
  return getCart(uid);
}
