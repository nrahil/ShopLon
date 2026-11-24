import { defineConfig } from "vitest/config";

// Integration tests run against the Postgres and Redis from docker compose,
// in their own database (shop_test) and Redis DB (2), so they never touch dev data.
export default defineConfig({
  test: {
    testTimeout: 30_000,
    hookTimeout: 60_000,
    globalSetup: ["test/integration/global-setup.ts"],
    env: {
      NODE_ENV: "test",
      LOG_LEVEL: "warn",
      DATABASE_URL: process.env.TEST_DATABASE_URL ?? "postgres://shop:shop@localhost:5432/shop_test",
      REDIS_URL: process.env.TEST_REDIS_URL ?? "redis://localhost:6379/2",
      FIREBASE_PROJECT_ID: "test-project",
      AUTH_ALLOW_DEV_TOKENS: "true",
      AUTH_DEV_SECRET: "integration-test-secret-integration-test-secret",
      PAYMENT_PROVIDER: "mock",
      MOCK_PSP_WEBHOOK_SECRET: "whsec_integration",
      RESERVATION_TTL_SECONDS: "900",
    },
  },
});
