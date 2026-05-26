defmodule SmartKioskCore.Repo.Migrations.CreateShopsWithDeliveryZone do
  use Ecto.Migration

  @moduledoc """
  Enable PostGIS (when permitted) and add a `delivery_zone` column to `shops`.

  - If PostGIS can be enabled, `delivery_zone` is added as a `geometry` column
    (Polygon, SRID 4326) and a GiST spatial index is created.
  - If PostGIS cannot be enabled (common on non-superuser roles), we fall back
    to a `jsonb` column to store GeoJSON.
  """

  def up do
    # IMPORTANT:
    # - `execute/1` is queued, so try/rescue won't catch DB errors.
    # - Even if we rescue a query error, PostgreSQL marks the whole migration
    #   transaction as aborted. Use a SAVEPOINT so we can recover and proceed.
    created = try_create_postgis_extension?()

    if table_exists?("shops") do
      add_delivery_zone_column(created)
    else
      raise """
      Expected `shops` table to already exist.

      This migration only adds the delivery zone column to the existing `shops`
      table created by an earlier migration.
      """
    end
  end

  def down do
    execute("DROP INDEX IF EXISTS shops_delivery_zone_gist")

    execute("""
    ALTER TABLE shops
    DROP COLUMN IF EXISTS delivery_zone
    """)
  end

  defp try_create_postgis_extension? do
    db = repo()

    # A SAVEPOINT allows us to rollback only the failed extension creation,
    # preventing "current transaction is aborted" for the rest of the migration.
    _ = db.query!("SAVEPOINT postgis_ext", [])

    case db.query("CREATE EXTENSION IF NOT EXISTS postgis", []) do
      {:ok, _} ->
        _ = db.query!("RELEASE SAVEPOINT postgis_ext", [])
        true

      {:error, _reason} ->
        _ = db.query!("ROLLBACK TO SAVEPOINT postgis_ext", [])
        _ = db.query!("RELEASE SAVEPOINT postgis_ext", [])

        IO.puts(
          "[migration] skipping PostGIS extension creation (insufficient privileges). Falling back to JSONB delivery_zone column."
        )

        false
    end
  end

  defp add_delivery_zone_column(postgis_enabled?) do
    if postgis_enabled? do
      execute("""
      ALTER TABLE shops
      ADD COLUMN IF NOT EXISTS delivery_zone geometry
      """)

      execute("CREATE INDEX IF NOT EXISTS shops_delivery_zone_gist ON shops USING GIST (delivery_zone)")
    else
      execute("""
      ALTER TABLE shops
      ADD COLUMN IF NOT EXISTS delivery_zone jsonb
      """)
    end
  end

  defp table_exists?(table_name) when is_binary(table_name) do
    %{rows: [[exists?]]} =
      repo().query!(
        """
        SELECT EXISTS (
          SELECT 1
          FROM information_schema.tables
          WHERE table_schema = 'public' AND table_name = $1
        )
        """,
        [table_name]
      )

    exists?
  end
end
