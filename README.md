# SmartKiosk — Kenya SME Commerce Platform

Phoenix Umbrella · Elixir · PostgreSQL · LiveView · PETAL Stack

## Quick Start

```bash
# 1. Install Elixir, Erlang, Node via asdf
bash setup_env.sh

# 2. Get dependencies
mix deps.get

# 3. Copy env and fill in your values
cp .env.example .env

# 4. Create DB, run migrations, seed categories + demo shop
mix ecto.setup

# 5. Start the server
mix phx.server
# → http://localhost:4000

# Start Meilisearch (separate terminal)
meilisearch --master-key=localdevkey
```

## Dev credentials (after seed)

| Role | Email | Password |
|------|-------|----------|
| Platform Admin | admin@smartkiosk.co.ke | AdminPassword123! |
| Demo Owner (Mama Grace Shop) | grace@example.com | DemoPassword123! |

## Umbrella app structure

```
smart_kiosk/
  apps/
    smart_kiosk_core/       ← Repo, schemas, contexts, migrations
    smart_kiosk_web/        ← Phoenix web + LiveView + API
  config/
    config.exs              ← Shared config
    dev.exs
    test.exs
    runtime.exs             ← Prod env vars
```

## Key contexts in smart_kiosk_core

| Context | Module | Responsibility |
|---------|--------|---------------|
| Accounts | `SmartKioskCore.Accounts` | Users, auth, shop registration |
| Catalogue | `SmartKioskCore.Catalogue` | Products, categories, inventory |
| Orders | `SmartKioskCore.Orders` | Order lifecycle, stock adjustment |
| Tenant | `SmartKioskCore.Tenant` | Row-level multi-tenancy scoping |

## Multi-tenancy

Every shop-owned table has a `shop_id` column.
All context functions that touch shop data accept a `%Shop{}` struct and
pipe queries through `SmartKioskCore.Tenant.scope/2` before executing.

**Never** query shop-owned tables without scoping. Example:

```elixir
# correct
Product |> scope(shop) |> Repo.all()

# wrong — returns all products across all shops
Repo.all(Product)
```

## Rider stub (Phase 1)

The rider mobile app (React Native / Flutter) is out of scope for Phase 1.
A stub REST API is provided at `/api/rider/*` that:
- Accepts location updates and broadcasts them over PubSub
- Returns delivery task queues
- Accepts task status updates

This stub keeps the delivery logic testable without the native app.
Replace stub implementations in `RiderStubController` in Phase 3.

## Running tests

```bash
mix test
mix test --cover
```

## Resetting the database

```bash
mix ecto.reset   # drops + recreates + seeds
```

## Generating a secret key for production

```bash
mix phx.gen.secret
```

