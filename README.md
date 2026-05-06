# SmartKiosk

Multi-tenant commerce platform for Kenyan SMEs — built with Elixir, Phoenix LiveView, and PostgreSQL.

**Stack:** Phoenix Umbrella · LiveView · Oban · Ecto · PostgreSQL · Tailwind CSS · daisyUI

---

## Quick Start

```bash
# 1. Install dependencies
mix deps.get

# 2. Create DB, run migrations, seed categories + demo shop
mix ecto.setup

# 3. Start the server
mix phx.server
# → http://localhost:4000
```

### Prerequisites

- Elixir 1.16+
- Erlang/OTP 26+
- PostgreSQL 14+ (with `uuid-ossp` and `citext` extensions available)

---

## Dev credentials (after seed)

| Role | Email | Password |
|------|-------|----------|
| Platform Admin | admin@smartkiosk.co.ke | AdminPassword123! |
| Demo Shop Owner (Mama Grace Shop) | grace@example.com | DemoPassword123! |

---

## Umbrella structure

```
smart_kiosk_umbrella/
├── apps/
│   ├── smart_kiosk_core/       ← Repo, schemas, contexts, Oban jobs, migrations
│   └── smart_kiosk_web/        ← Phoenix endpoint, LiveView, controllers, API
├── config/
│   ├── config.exs              ← Shared config
│   ├── dev.exs
│   ├── test.exs
│   └── runtime.exs             ← Production env vars
└── mix.exs                     ← Umbrella root
```

---

## Contexts (`smart_kiosk_core`)

| Context | Module | Responsibility |
|---------|--------|----------------|
| Accounts | `SmartKioskCore.Accounts` | Users, auth tokens, password reset |
| Catalogue | `SmartKioskCore.Catalogue` | Products, categories, inventory, stock |
| Orders | `SmartKioskCore.Orders` | Order lifecycle, status transitions, stock deduction |
| Tenant | `SmartKioskCore.Tenant` | Row-level multi-tenancy query scoping |

---

## Schemas

| Schema | Table | Notes |
|--------|-------|-------|
| `Shop` | `shops` | Top-level tenant |
| `User` | `users` | Roles: `platform_admin`, `owner`, `manager`, `staff`, `rider` |
| `UserToken` | `users_tokens` | Session + confirmation tokens |
| `Category` | `categories` | Hierarchical, global (not per-shop) |
| `Product` | `products` | Shop-scoped, with JSONB attributes |
| `ProductImage` | `product_images` | Ordered images per product |
| `Customer` | `customers` | Shop-scoped customer records |
| `Order` | `orders` | Shop-scoped order with status machine |
| `OrderItem` | `order_items` | Price-snapshotted line items |
| `Transaction` | `transactions` | Payment records |
| `Rider` | `riders` | Delivery rider profile linked to a User |
| `DeliveryZone` | `delivery_zones` | Zone boundaries and base fees |
| `Delivery` | `deliveries` | Delivery task assigned to a Rider |
| `Campaign` | `campaigns` | Advertising campaigns |
| `AdCreative` | `ad_creatives` | Individual creatives per campaign |
| `AdEvent` | `ad_events` | Append-only impression/click log |
| `Subscription` | `subscriptions` | One per shop — plan and billing status |
| `Invoice` | `invoices` | Billing invoices per subscription period |

---

## Multi-tenancy

Every shop-owned table has a `shop_id` column. All context functions that touch shop data accept a `%Shop{}` struct and scope queries through `SmartKioskCore.Tenant.scope/2`.

```elixir
# correct — scoped to shop
Product |> scope(shop) |> Repo.all()

# wrong — returns products across all shops
Repo.all(Product)
```

Never query shop-owned tables without scoping through the context functions.

---

## Subscription plans

| Plan | Target |
|------|--------|
| `:kiosk` | Single-location micro-business |
| `:duka` | Small shop with light inventory |
| `:biashara` | Growing business, multi-staff |
| `:enterprise` | Large retailer, custom terms |

---

## Background jobs (Oban)

Oban is configured in `smart_kiosk_core` with two queues:

| Queue | Concurrency | Purpose |
|-------|-------------|---------|
| `default` | 10 | General async work |
| `mailer` | 5 | Transactional email delivery |

---

## Rider API stub (Phase 1)

The rider mobile app (React Native / Flutter) is deferred to Phase 3.
A REST stub is available at `/api/rider/*` to keep delivery logic testable:

| Endpoint | Description |
|----------|-------------|
| `POST /api/rider/location` | Update GPS coordinates + availability status |
| `GET /api/rider/tasks` | Fetch pending/active delivery queue |
| `POST /api/rider/tasks/:id/status` | Update delivery status |

All endpoints require `Authorization: Bearer <session_token>`.
Replace stub implementations in `SmartKioskWeb.Api.RiderStubController` in Phase 3.

---

## Common commands

```bash
# Reset database (drop + recreate + seed)
mix ecto.reset

# Run tests
mix test
mix test --cover

# Run the precommit check (compile with warnings-as-errors, format, test)
mix precommit

# Generate a secret key for production
mix phx.gen.secret

# Open interactive console
iex -S mix phx.server
```

---

## Planned (Phase 3+)

- PostGIS extension for geospatial delivery zone queries
- M-Pesa STK Push payment integration (`MpesaCallbackController`)
- Rider mobile app (React Native / Flutter) replacing the stub API
- Ad analytics aggregation (nightly Oban jobs)
