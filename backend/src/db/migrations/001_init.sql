-- ShopLon core schema. All money is stored as integer cents.

CREATE TABLE users (
  id           text PRIMARY KEY,            -- Firebase UID
  email        text,
  -- Version of the cart last written behind from Redis. A flush only
  -- applies if its snapshot is newer, so out-of-order flushes can't regress it.
  cart_version bigint NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  slug  text PRIMARY KEY,
  name  text NOT NULL
);

CREATE TABLE products (
  id               text PRIMARY KEY,       -- e.g. "dj_12"
  title            text NOT NULL,
  description      text NOT NULL DEFAULT '',
  brand            text,
  category         text NOT NULL REFERENCES categories(slug),
  price_cents      integer NOT NULL CHECK (price_cents >= 0),
  discount_percent integer NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 90),
  -- The database itself refuses to oversell, even if application code has a bug.
  stock            integer NOT NULL CHECK (stock >= 0),
  rating           numeric(3,2) NOT NULL DEFAULT 0,
  thumbnail        text NOT NULL DEFAULT '',
  images           jsonb NOT NULL DEFAULT '[]',
  reviews          jsonb NOT NULL DEFAULT '[]',
  details          jsonb NOT NULL DEFAULT '{}',  -- shipping, warranty and return policy text
  active           boolean NOT NULL DEFAULT true,
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX products_category_idx ON products (category, id) WHERE active;

-- Durable copy of carts. The hot copy lives in Redis and is flushed here
-- asynchronously (write-behind). See src/modules/cart.
CREATE TABLE cart_items (
  user_id     text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  line_key    text NOT NULL,               -- productId|size|color
  product_id  text NOT NULL REFERENCES products(id),
  quantity    integer NOT NULL CHECK (quantity > 0),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, line_key)
);

CREATE TYPE order_status AS ENUM (
  'PENDING_PAYMENT', 'PAID', 'SHIPPED', 'CANCELLED', 'EXPIRED', 'REFUND_PENDING', 'REFUNDED'
);

CREATE TABLE orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         text NOT NULL REFERENCES users(id),
  status          order_status NOT NULL DEFAULT 'PENDING_PAYMENT',
  currency        char(3) NOT NULL,
  subtotal_cents  integer NOT NULL,
  shipping_cents  integer NOT NULL,
  tax_cents       integer NOT NULL,
  total_cents     integer NOT NULL CHECK (total_cents > 0),
  item_count      integer NOT NULL,
  -- Stock is held until this time. After it, an unpaid order expires and its stock is released.
  expires_at      timestamptz NOT NULL,
  -- True while this order holds stock. It is flipped exactly once on release,
  -- which makes releasing stock idempotent.
  stock_reserved  boolean NOT NULL DEFAULT true,
  version         integer NOT NULL DEFAULT 1,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_user_idx ON orders (user_id, created_at DESC, id DESC);
CREATE INDEX orders_pending_expiry_idx ON orders (expires_at) WHERE status = 'PENDING_PAYMENT';

CREATE TABLE order_items (
  order_id          uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  line_no           integer NOT NULL,
  product_id        text NOT NULL REFERENCES products(id),
  -- Snapshot of what was bought, so later catalogue edits don't rewrite history.
  title             text NOT NULL,
  thumbnail         text NOT NULL,
  unit_price_cents  integer NOT NULL,
  quantity          integer NOT NULL CHECK (quantity > 0),
  selected_size     text,
  selected_color    text,
  PRIMARY KEY (order_id, line_no)
);

CREATE TYPE payment_status AS ENUM ('CREATED', 'SUCCEEDED', 'FAILED', 'REFUND_PENDING', 'REFUNDED');

CREATE TABLE payments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        uuid NOT NULL REFERENCES orders(id),
  provider        text NOT NULL,
  provider_ref    text,                    -- the PSP's id (payment intent or checkout session)
  status          payment_status NOT NULL DEFAULT 'CREATED',
  amount_cents    integer NOT NULL,
  currency        char(3) NOT NULL,
  client_secret   text,
  redirect_url    text,
  failure_reason  text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX payments_provider_ref_uq ON payments (provider, provider_ref) WHERE provider_ref IS NOT NULL;
-- At most one open payment attempt per order.
CREATE UNIQUE INDEX payments_one_open_per_order_uq ON payments (order_id) WHERE status = 'CREATED';
CREATE INDEX payments_open_idx ON payments (created_at) WHERE status = 'CREATED';
CREATE INDEX payments_order_idx ON payments (order_id);

-- Webhook de-duplication: payment providers deliver at-least-once.
CREATE TABLE webhook_events (
  provider     text NOT NULL,
  event_id     text NOT NULL,
  type         text NOT NULL,
  received_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (provider, event_id)
);

-- Idempotency keys for unsafe client requests (checkout, pay).
CREATE TABLE idempotency_keys (
  user_id        text NOT NULL,
  key            text NOT NULL,
  route          text NOT NULL,
  request_hash   text NOT NULL,
  status         text NOT NULL CHECK (status IN ('IN_PROGRESS', 'COMPLETED')),
  response_code  integer,
  response_body  jsonb,
  locked_until   timestamptz NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key)
);
CREATE INDEX idempotency_keys_created_idx ON idempotency_keys (created_at);

-- Transactional outbox. Events are written in the same transaction as the
-- state change, then relayed to the queue by the worker: no lost or phantom events.
CREATE TABLE outbox (
  id            bigserial PRIMARY KEY,
  aggregate_id  text NOT NULL,
  type          text NOT NULL,
  payload       jsonb NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  published_at  timestamptz
);
CREATE INDEX outbox_unpublished_idx ON outbox (id) WHERE published_at IS NULL;
