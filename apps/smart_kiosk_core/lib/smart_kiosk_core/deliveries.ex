defmodule SmartKioskCore.Deliveries do
  @moduledoc """
  The Deliveries context.
  Handles delivery zones, rider assignments, and delivery tracking.
  """

  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{DeliveryZone, Rider, Delivery}

  # ── Delivery Zones ───────────────────────────────────────────────────────────

  @doc "Lists all delivery zones."
  def list_delivery_zones do
    Repo.all(DeliveryZone)
  end

  @doc "Gets a delivery zone by id."
  def get_delivery_zone!(id), do: Repo.get!(DeliveryZone, id)

  @doc "Creates a delivery zone."
  def create_delivery_zone(attrs \\ %{}) do
    %DeliveryZone{}
    |> DeliveryZone.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a delivery zone."
  def update_delivery_zone(%DeliveryZone{} = zone, attrs) do
    zone
    |> DeliveryZone.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a delivery zone."
  def delete_delivery_zone(%DeliveryZone{} = zone) do
    Repo.delete(zone)
  end

  @doc "Finds the matching delivery zone for a given coordinate."
  def find_zone_for_location(_lat, _lng) do
    # Fallback logic without PostGIS
    # In production with PostGIS, we use ST_Contains.
    # For now, we return the first active zone as a placeholder.
    DeliveryZone
    |> where([z], z.active == true)
    |> limit(1)
    |> Repo.one()
  end

  # ── Riders ───────────────────────────────────────────────────────────────────

  @doc "Finds the nearest available rider for a shop's pickup location."
  def assign_nearest_rider(%{id: shop_id}, _pickup_lat, _pickup_lng) do
    # Fallback logic without PostGIS
    # In production with PostGIS, we use ST_Distance.
    # For now, we return the first available rider for the shop.
    Rider
    |> join(:inner, [r], u in SmartKioskCore.Schemas.User, on: r.user_id == u.id)
    |> where([r, u], u.shop_id == ^shop_id)
    |> where([r, u], r.status == :available)
    |> where([r, u], r.verification_status == :verified)
    |> limit(1)
    |> Repo.one()
  end
end
