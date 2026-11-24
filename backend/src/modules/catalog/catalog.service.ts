import { pool, type Db } from "../../db/pool.js";
import { cached, cacheNamespace } from "../../lib/cache.js";
import { discounted } from "../../lib/money.js";

export interface ProductRow {
  id: string;
  title: string;
  description: string;
  brand: string | null;
  category: string;
  price_cents: number;
  discount_percent: number;
  stock: number;
  rating: string;
  thumbnail: string;
  images: string[];
  reviews: unknown[];
  details: Record<string, string | null>;
}

export interface ProductDto {
  id: string;
  title: string;
  description: string;
  brand: string | null;
  category: string;
  priceCents: number;
  discountPercent: number;
  /** What the customer pays per unit, after discount. */
  salePriceCents: number;
  stock: number;
  rating: number;
  thumbnail: string;
  images: string[];
  reviews: unknown[];
  shippingInformation: string | null;
  warrantyInformation: string | null;
  returnPolicy: string | null;
}

export const PRODUCT_COLUMNS = `id, title, description, brand, category, price_cents, discount_percent, stock,
  rating, thumbnail, images, reviews, details`;

export function toDto(r: ProductRow): ProductDto {
  return {
    id: r.id,
    title: r.title,
    description: r.description,
    brand: r.brand,
    category: r.category,
    priceCents: r.price_cents,
    discountPercent: r.discount_percent,
    salePriceCents: discounted(r.price_cents, r.discount_percent),
    stock: r.stock,
    rating: Number(r.rating),
    thumbnail: r.thumbnail,
    images: r.images,
    reviews: r.reviews,
    shippingInformation: r.details.shippingInformation ?? null,
    warrantyInformation: r.details.warrantyInformation ?? null,
    returnPolicy: r.details.returnPolicy ?? null,
  };
}

export interface ProductPage {
  items: ProductDto[];
  nextCursor: string | null;
}

/**
 * Keyset pagination (WHERE id > cursor ORDER BY id) stays fast at any depth,
 * unlike OFFSET, which scans and discards every skipped row.
 * Results are cached for ~30 s. Stock shown here can be slightly stale, which
 * is fine: checkout re-checks stock under a row lock.
 */
export async function listProducts(opts: { category?: string; cursor?: string; limit: number }): Promise<ProductPage> {
  const ns = await cacheNamespace("catalog");
  const key = `${ns}:list:${opts.category ?? "*"}:${opts.cursor ?? ""}:${opts.limit}`;
  return cached(key, 30, async () => {
    const { rows } = await pool.query<ProductRow>(
      `SELECT ${PRODUCT_COLUMNS} FROM products
       WHERE active AND ($1::text IS NULL OR category = $1) AND ($2::text IS NULL OR id > $2)
       ORDER BY id LIMIT $3`,
      [opts.category ?? null, opts.cursor ?? null, opts.limit + 1],
    );
    const page = rows.slice(0, opts.limit);
    return {
      items: page.map(toDto),
      nextCursor: rows.length > opts.limit ? (page[page.length - 1]?.id ?? null) : null,
    };
  });
}

export async function getProduct(id: string): Promise<ProductDto | null> {
  const ns = await cacheNamespace("catalog");
  return cached(`${ns}:product:${id}`, 15, async () => {
    const { rows } = await pool.query<ProductRow>(`SELECT ${PRODUCT_COLUMNS} FROM products WHERE id = $1 AND active`, [
      id,
    ]);
    return rows[0] ? toDto(rows[0]) : null;
  });
}

export async function listCategories(): Promise<{ slug: string; name: string; productCount: number }[]> {
  const ns = await cacheNamespace("catalog");
  return cached(`${ns}:categories`, 300, async () => {
    const { rows } = await pool.query<{ slug: string; name: string; product_count: number }>(
      `SELECT c.slug, c.name, count(p.id)::int AS product_count
       FROM categories c LEFT JOIN products p ON p.category = c.slug AND p.active
       GROUP BY c.slug, c.name ORDER BY c.name`,
    );
    return rows.map((r) => ({ slug: r.slug, name: r.name, productCount: r.product_count }));
  });
}

/** Uncached lookup used when correctness matters (cart validation). */
export async function findProducts(db: Db, ids: string[]): Promise<Map<string, ProductRow>> {
  if (ids.length === 0) return new Map();
  const { rows } = await db.query<ProductRow>(
    `SELECT ${PRODUCT_COLUMNS} FROM products WHERE id = ANY($1::text[]) AND active`,
    [ids],
  );
  return new Map(rows.map((r) => [r.id, r]));
}
