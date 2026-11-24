import pg from "pg";

/** Recreates the shop_test database before integration tests (no-op for unit-only runs). */
export default async function setup({ provide: _provide }: { provide: unknown }) {
  const isIntegration = process.argv.some((a) => a.includes("integration"));
  if (!isIntegration) return;
  const url = new URL(process.env.TEST_DATABASE_URL ?? "postgres://shop:shop@localhost:5432/shop_test");
  const dbName = url.pathname.slice(1);
  url.pathname = "/postgres";
  const admin = new pg.Client({ connectionString: url.toString() });
  await admin.connect();
  await admin.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
  await admin.query(`CREATE DATABASE ${dbName}`);
  await admin.end();
}
