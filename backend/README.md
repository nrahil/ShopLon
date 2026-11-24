# ShopLon backend

TypeScript (Fastify) API, background worker and mock payment provider for the ShopLon app.
The design and its trade-offs are in [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

## Run everything

Requires Docker.

```bash
cd backend
cp .env.example .env            # then put random values in the secrets
docker compose up -d --build    # postgres, redis, setup, 2× api, worker, mock psp, nginx
curl localhost:8080/readyz      # {"status":"ready",...}
```

| URL | What |
|---|---|
| `http://localhost:8080` | API through nginx (load-balanced replicas) |
| `http://localhost:8090` | Mock payment provider |
| `localhost:5432` / `localhost:6379` | Postgres (`shop`/`shop`) / Redis |

The first start runs migrations and imports ~200 products from the public DummyJSON catalogue.
Re-import with `docker compose run --rm setup node dist/cli.js seed`.

Then run the app from the repo root: `flutter run -d chrome --web-port 5000`.
To point it at another API, add `--dart-define=API_BASE_URL=https://...`.

Scale out: `docker compose up -d --scale api=4 --scale worker=2`.

## Tests

```bash
npm install
npm test                    # unit tests (no services needed)
npm run test:integration    # needs postgres + redis from docker compose; uses its own shop_test DB
npm run load:flash-sale -- --buyers 500 --stock 25   # needs the full stack and dev tokens enabled
```

## API

All money is integer cents. Errors look like `{"error":{"code","message","details?"}}`.

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/v1/products?category=&cursor=&limit=` | – | keyset pagination, ETag, cached |
| GET | `/v1/products/:id` | – | |
| GET | `/v1/categories` | – | with product counts |
| GET | `/v1/cart` | ✓ | server-computed totals |
| POST | `/v1/cart/items` | ✓ | `{productId, quantity, size?, color?}`, increments |
| PUT | `/v1/cart/items/:lineKey` | ✓ | `{quantity}`, absolute (idempotent) |
| DELETE | `/v1/cart/items/:lineKey` | ✓ | |
| POST | `/v1/checkout` | ✓ | **requires `Idempotency-Key`**. Reserves stock, returns the order + payment attempt |
| GET | `/v1/orders`, `/v1/orders/:id` | ✓ | |
| POST | `/v1/orders/:id/payments` | ✓ | **requires `Idempotency-Key`**. New payment attempt |
| POST | `/v1/orders/:id/cancel` | ✓ | releases stock |
| GET | `/v1/auth/session` | ✓ | |
| POST | `/v1/auth/logout` | ✓ | revokes all tokens issued before now |
| POST | `/v1/webhooks/:provider` | signature | `mock` or `stripe` |
| GET | `/healthz`, `/readyz`, `/metrics` | – | `/metrics` is not exposed through nginx |

## Payments

`PAYMENT_PROVIDER=mock` (default) uses the bundled PSP. Test cards (any future expiry, any CVC):

| Card | Behaviour |
|---|---|
| 4242 4242 4242 4242 | succeeds |
| 4000 0000 0000 0002 | declined |
| 4000 0000 0000 9995 | insufficient funds |
| 4000 0000 0000 0259 | succeeds, webhook delivered **twice** (de-dup) |
| 4000 0000 0000 0341 | succeeds, webhook **never delivered** (reconciliation fixes it within ~1 min) |
| 4000 0000 0000 0077 | succeeds, webhook delayed 20 s |

`PAYMENT_PROVIDER=stripe` uses Stripe Checkout in test mode. Set `STRIPE_SECRET_KEY` and
`STRIPE_WEBHOOK_SECRET`, and forward webhooks with
`stripe listen --forward-to localhost:8080/v1/webhooks/stripe`.

## Layout

```
src/
  server.ts            API entry (graceful shutdown)
  worker.ts            write-behind, outbox relay, expiry, reconciliation, event consumers
  cli.ts               migrate | seed | setup
  config.ts            env validation (fails fast, guards unsafe production config)
  auth/                Firebase JWT verification, revocation, dev tokens for tests
  http/                Fastify app, idempotency, routes
  modules/
    catalog/           cache-aside catalogue
    cart/              Redis Lua store + write-behind
    orders/            state machine, inventory locking, checkout, expiry
    payments/          provider interface, mock + Stripe adapters, webhook handling, reconciliation
    outbox/            transactional outbox + relay
  mock-psp/            Stripe-shaped mock payment provider
  db/                  pool + transaction retry, migrations, seed
```
