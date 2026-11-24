# ShopLon

A full-stack e-commerce system: a responsive Flutter app (web, Android and iOS) on top of a horizontally
scalable TypeScript backend. It's built to show the hard parts done correctly: concurrent stock reservation,
high-write carts, idempotent checkout, payments that survive an unreliable provider, and secure sessions.

**Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the design, the trade-offs and the measured results.**

```
Flutter app ──► nginx ──► API × N (Fastify, stateless) ──► Postgres (source of truth)
     │                          │                    └──► Redis (carts, cache, rate limits, sessions)
     │                          └──► Payment provider (mock PSP or Stripe) ──signed webhooks──┐
     └── card details go straight to the PSP, never to our API                               │
                                 Worker (write-behind, outbox, expiry, reconciliation) ◄──────┘
```

## Highlights

- **No overselling under load**: 500 simultaneous buyers for 25 units produce exactly 25 paid orders
  (`npm run load:flash-sale`). Row locks are taken in a deterministic order, with a DB constraint as backstop.
- **Idempotent checkout and payments**: double taps and network retries never create a second order or charge.
- **High-write cart**: atomic Redis Lua scripts, written behind to Postgres in coalesced, version-guarded batches.
- **Payment correctness**: signed and de-duplicated webhooks, an order state machine, reconciliation for lost
  webhooks, and automatic refunds for late or duplicate payments.
- **Security**: Firebase JWTs verified against Google's keys, server-side session revocation, per-user rate
  limits shared across replicas, PCI-scope reduction, validated input, and locked-down Firestore rules.
- **Operations**: transactional outbox, health and readiness probes, Prometheus metrics, request ids,
  graceful shutdown, and single-run migrations.
- 30 backend tests (unit + integration against real Postgres/Redis) and 18 Flutter tests.

## Run it

```bash
# 1. Backend: Postgres, Redis, 2 API replicas, worker, mock PSP, nginx
cd backend && cp .env.example .env && docker compose up -d --build

# 2. App
cd .. && flutter pub get && flutter run -d chrome --web-port 5000
```

Sign up in the app, add items, check out, and pay with test card `4242 4242 4242 4242`.
Other test cards simulate declines, duplicate webhooks and lost webhooks (see [`backend/README.md`](backend/README.md)).

## Repository

| Path | |
|---|---|
| `lib/` | Flutter app (Provider state management, responsive layouts, API client with token refresh, retries and idempotency) |
| `backend/` | API, worker, mock PSP, migrations, tests, load test, Docker Compose |
| `docs/ARCHITECTURE.md` | Design write-up with diagrams |
| `firestore.rules` | Firestore holds only wishlists; everything else is closed to clients |
