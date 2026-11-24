import { pool, withTransaction } from "./pool.js";
import { logger } from "../lib/logger.js";
import { toCents } from "../lib/money.js";

const SOURCE = "https://dummyjson.com";

interface DjProduct {
  id: number;
  title: string;
  description?: string;
  brand?: string;
  category: string;
  price: number;
  discountPercentage?: number;
  stock?: number;
  rating?: number;
  thumbnail?: string;
  images?: string[];
  reviews?: unknown[];
  shippingInformation?: string;
  warrantyInformation?: string;
  returnPolicy?: string;
}

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(`${SOURCE}${path}`, { signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`GET ${path} -> ${res.status}`);
  return (await res.json()) as T;
}

/**
 * Imports the public DummyJSON catalogue into Postgres. Safe to run repeatedly:
 * catalogue fields are upserted, but live stock is left alone unless
 * `resetStock` is set, so re-seeding never undoes sales.
 */
export async function seedCatalogue({ resetStock = false } = {}): Promise<number> {
  const [categories, { products }] = await Promise.all([
    getJson<{ slug: string; name: string }[]>("/products/categories"),
    getJson<{ products: DjProduct[] }>("/products?limit=0"),
  ]);

  await withTransaction(async (db) => {
    await db.query(
      `INSERT INTO categories (slug, name)
       SELECT * FROM unnest($1::text[], $2::text[])
       ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name`,
      [categories.map((c) => c.slug), categories.map((c) => c.name)],
    );

    for (const p of products) {
      const discount = Math.round(p.discountPercentage ?? 0);
      await db.query(
        `INSERT INTO products (id, title, description, brand, category, price_cents, discount_percent,
                               stock, rating, thumbnail, images, reviews, details)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
         ON CONFLICT (id) DO UPDATE SET
           title = EXCLUDED.title, description = EXCLUDED.description, brand = EXCLUDED.brand,
           category = EXCLUDED.category, price_cents = EXCLUDED.price_cents,
           discount_percent = EXCLUDED.discount_percent, rating = EXCLUDED.rating,
           thumbnail = EXCLUDED.thumbnail, images = EXCLUDED.images, reviews = EXCLUDED.reviews,
           details = EXCLUDED.details, updated_at = now()
           ${resetStock ? ", stock = EXCLUDED.stock" : ""}`,
        [
          `dj_${p.id}`,
          p.title,
          p.description ?? "",
          p.brand ?? null,
          p.category,
          toCents(p.price),
          discount >= 1 ? Math.min(discount, 90) : 0,
          Math.max(0, p.stock ?? 0),
          p.rating ?? 0,
          p.thumbnail ?? p.images?.[0] ?? "",
          JSON.stringify(p.images ?? []),
          JSON.stringify(p.reviews ?? []),
          JSON.stringify({
            shippingInformation: p.shippingInformation ?? null,
            warrantyInformation: p.warrantyInformation ?? null,
            returnPolicy: p.returnPolicy ?? null,
          }),
        ],
      );
    }
  });
  logger.info({ categories: categories.length, products: products.length }, "catalogue seeded");
  return products.length;
}

/** Seeds only when the catalogue is empty (used on first start). */
export async function seedIfEmpty(): Promise<void> {
  const { rows } = await pool.query<{ n: number }>("SELECT count(*)::int AS n FROM products");
  if ((rows[0]?.n ?? 0) === 0) await seedCatalogue({ resetStock: true });
}
