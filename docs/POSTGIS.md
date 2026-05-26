PostGIS setup and migration notes

Overview

This project currently stores delivery zone boundaries as GeoJSON in a JSONB `boundary` column. For robust spatial queries (ST_Contains, ST_Distance, indexing), enable PostGIS and store geometries in a `geometry` column with a GiST index.

Steps

1) Add PostGIS to your PostgreSQL database

Run as a DB superuser (psql):

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology; -- optional
```

2) Add the `geo_postgis` (or `geo`) Elixir library

In `mix.exs` (apps/smart_kiosk_core):

```elixir
# add to deps
{:geo_postgis, "~> 3.4"}
```

Then run in the assets root:

```bash
mix deps.get
```

3) Add an Ecto migration to populate and index geometry

Create a migration (example):

```elixir
defmodule SmartKioskCore.Repo.Migrations.AddDeliveryZonesGeometry do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS postgis")

    alter table(:delivery_zones) do
      add :boundary_geom, :geometry
    end

    # populate geometry from existing GeoJSON boundary JSONB where present
    execute("UPDATE delivery_zones SET boundary_geom = ST_SetSRID(ST_GeomFromGeoJSON(boundary::text), 4326) WHERE boundary IS NOT NULL")

    execute("CREATE INDEX delivery_zones_boundary_geom_idx ON delivery_zones USING GIST (boundary_geom)")
  end

  def down do
    execute("DROP INDEX IF EXISTS delivery_zones_boundary_geom_idx")

    alter table(:delivery_zones) do
      remove :boundary_geom
    end
  end
end
```

4) Update schema to use `Geo.PostGIS.Geometry` (optional)

In `SmartKioskCore.Schemas.DeliveryZone`:

```elixir
field :boundary_geom, Geo.PostGIS.Geometry
```

5) Querying with PostGIS

Replace the fallback loop with a DB query using `ST_Contains`:

```elixir
from(z in DeliveryZone,
  where: z.active == true and fragment("ST_Contains(?, ST_SetSRID(ST_Point(?, ?), 4326))", z.boundary_geom, ^lng, ^lat),
  limit: 1
)
|> Repo.one()
```

6) Notes

- `ST_GeomFromGeoJSON` expects GeoJSON with longitude/latitude order ([lon, lat]).
- Use SRID 4326 for WGS84 lat/lng.
- Add tests and validate that existing `boundary` JSONB values are valid GeoJSON before converting.
- Consider installing `postgis` in local dev container or Docker image—example for Docker:

```dockerfile
# add in your postgres image
RUN apt-get update && apt-get install -y postgis postgresql-15-postgis-3
```

7) Rolling changes

- Run the migration; inspect `boundary_geom` values and drop the JSONB `boundary` column only after verification (or keep it as a source-of-truth for editing in the UI).

8) UI integration

- When PostGIS is enabled, the map-drawing UI can export GeoJSON; when saving, the server can call `ST_GeomFromGeoJSON(boundary_json)` to populate `boundary_geom` and persist both forms (JSONB + geometry).

If you'd like, I can generate the migration file and update the schema to add `boundary_geom` now (and include a small Ecto migration file).