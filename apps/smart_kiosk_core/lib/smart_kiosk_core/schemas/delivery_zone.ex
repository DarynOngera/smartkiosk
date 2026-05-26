defmodule SmartKioskCore.Schemas.DeliveryZone do
  @moduledoc """
  Geographic delivery zone.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "delivery_zones" do
    field(:name, :string)
    # GeoJSON Polygon
    field(:boundary, :map)
    field(:base_fee, :decimal)
    field(:active, :boolean, default: true)

    belongs_to(:shop, SmartKioskCore.Schemas.Shop)
    has_many(:deliveries, SmartKioskCore.Schemas.Delivery)

    timestamps(type: :utc_datetime)
  end

  def changeset(zone, attrs) do
    attrs = normalize_attrs(attrs)

    zone
    |> cast(attrs, [:name, :boundary, :base_fee, :active, :shop_id])
    |> validate_required([:name, :base_fee])
    |> validate_number(:base_fee, greater_than_or_equal_to: 0)
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    boundary_key = if Map.has_key?(attrs, :boundary), do: :boundary, else: "boundary"

    case Map.get(attrs, boundary_key) || Map.get(attrs, :boundary) || Map.get(attrs, "boundary") do
      boundary when is_binary(boundary) ->
        parsed_boundary =
          boundary
          |> String.trim()
          |> case do
            "" -> nil
            json -> Jason.decode(json)
          end
          |> case do
            {:ok, decoded} -> decoded
            _ -> boundary
          end

        Map.put(attrs, boundary_key, parsed_boundary)

      _ ->
        attrs
    end
  end

  defp normalize_attrs(attrs), do: attrs
end
