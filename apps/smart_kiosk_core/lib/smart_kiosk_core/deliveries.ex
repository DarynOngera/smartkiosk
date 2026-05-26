defmodule SmartKioskCore.Deliveries do
  @moduledoc """
  The Deliveries context.
  Handles delivery zones, rider assignments, and delivery tracking.
  """

  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{DeliveryZone, Delivery, Order, Shop}
  alias SmartKioskCore.Shops

  # ── Delivery Zones ───────────────────────────────────────────────────────────

  @doc "Lists all delivery zones."
  def list_delivery_zones do
    Repo.all(DeliveryZone)
  end

  def list_delivery_zones(%Shop{id: shop_id}, opts \\ []) do
    active_only = Keyword.get(opts, :active_only, false)

    DeliveryZone
    |> where([z], z.shop_id == ^shop_id)
    |> maybe_filter_active(active_only)
    |> Repo.all()
  end

  @doc "Gets a delivery zone by id."
  def get_delivery_zone!(id), do: Repo.get!(DeliveryZone, id)

  def get_delivery_zone!(%Shop{id: shop_id}, id) do
    DeliveryZone
    |> where([z], z.id == ^id and z.shop_id == ^shop_id)
    |> Repo.one!()
  end

  @doc "Creates a delivery zone."
  def create_delivery_zone(attrs \\ %{}, shop \\ nil) do
    attrs =
      case shop do
        %Shop{id: shop_id} ->
          shop_key = if Map.has_key?(attrs, :shop_id), do: :shop_id, else: "shop_id"
          Map.put_new(attrs, shop_key, shop_id)

        _ ->
          attrs
      end

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

  @doc """
  Creates a delivery for an online order after validating the customer dropoff
  point against the shop's delivery zone. Rider assignment is handled separately
  by the shop owner.
  """
  def prepare_delivery_point(%Shop{} = shop, delivery_attrs) when is_map(delivery_attrs) do
    prepare_dropoff(shop, delivery_attrs)
  end

  def create_delivery_for_order(%Order{} = order, %Shop{} = shop, delivery_attrs)
      when is_map(delivery_attrs) do
    with {:ok, pickup_lat, pickup_lng} <- pickup_coordinates(shop),
         {:ok, zone, dropoff_lat, dropoff_lng} <- prepare_dropoff(shop, delivery_attrs),
         {:ok, delivery} <-
           %Delivery{}
           |> Delivery.changeset(%{
             order_id: order.id,
             delivery_zone_id: zone.id,
             pickup_lat: pickup_lat,
             pickup_lng: pickup_lng,
             dropoff_lat: dropoff_lat,
             dropoff_lng: dropoff_lng,
             notes: Map.get(delivery_attrs, :notes) || Map.get(delivery_attrs, "notes")
           })
           |> Repo.insert() do
      {:ok, delivery}
    else
      false -> {:error, :delivery_point_outside_zone}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Finds the matching delivery zone for a given coordinate."
  def find_zone_for_location(lat, lng) do
    # Prefer PostGIS in production (ST_Contains). If PostGIS is not available
    # use the stored GeoJSON `boundary` fields and do a point-in-polygon test
    # as a fallback so zone matching works without DB spatial extensions.

    # Fallback: iterate active zones and test boundaries stored as GeoJSON
    DeliveryZone
    |> where([z], z.active == true)
    |> Repo.all()
    |> Enum.find(fn zone ->
      case zone.boundary do
        %{"type" => "Polygon", "coordinates" => coords} when is_list(coords) and coords != [] ->
          point_in_geojson_polygon?(lng, lat, coords)

        _ ->
          false
      end
    end)
  end

  # GeoJSON Polygon coords look like [ [ [lng, lat], [lng, lat], ... ] , ... ]
  defp point_in_geojson_polygon?(point_x, point_y, [outer_ring | _holes]) do
    # We only consider the outer ring for now. Use ray-casting algorithm.
    ring = outer_ring

    ring
    |> Enum.map(fn [x, y] -> {x, y} end)
    |> point_in_polygon?({point_x, point_y})
  rescue
    _ -> false
  end

  # Ray casting algorithm for point in polygon. Points are {x, y} tuples.
  defp point_in_polygon?(vertices, {px, py}) when is_list(vertices) do
    vertices_count = length(vertices)

    vertices
    |> Enum.with_index()
    |> Enum.reduce(false, fn {{x_i, y_i}, i}, acc ->
      {x_j, y_j} = Enum.at(vertices, rem(i + 1, vertices_count))

      intersect =
        y_i > py != y_j > py and
          px < (x_j - x_i) * (py - y_i) / (y_j - y_i + 0.0) + x_i

      if intersect, do: !acc, else: acc
    end)
  end

  defp maybe_filter_active(query, true), do: where(query, [z], z.active == true)
  defp maybe_filter_active(query, false), do: query

  # ── Riders ───────────────────────────────────────────────────────────────────

  # Rider assignment is now handled separately by the shop owner
  # after the order is created

  defp pickup_coordinates(%Shop{lat: lat, lng: lng}) when is_number(lat) and is_number(lng),
    do: {:ok, lat, lng}

  defp pickup_coordinates(%Shop{} = shop) do
    # Fallback: use the first delivery zone's centroid if shop has no coordinates
    case Repo.get_by(SmartKioskCore.Schemas.DeliveryZone, shop_id: shop.id, active: true) do
      nil ->
        {:error, :missing_pickup_location}

      zone ->
        case calculate_zone_centroid(zone.boundary) do
          {:ok, lat, lng} -> {:ok, lat, lng}
          {:error, _} -> {:error, :missing_pickup_location}
        end
    end
  end

  defp prepare_dropoff(%Shop{} = shop, delivery_attrs) do
    zone_id =
      Map.get(delivery_attrs, :delivery_zone_id) || Map.get(delivery_attrs, "delivery_zone_id")

    delivery_point =
      Map.get(delivery_attrs, :delivery_address) || Map.get(delivery_attrs, "delivery_address")

    lat = Map.get(delivery_attrs, :delivery_lat) || Map.get(delivery_attrs, "delivery_lat")
    lng = Map.get(delivery_attrs, :delivery_lng) || Map.get(delivery_attrs, "delivery_lng")

    cond do
      is_nil(zone_id) or zone_id == "" ->
        {:error, :missing_delivery_zone}

      is_number(lat) and is_number(lng) ->
        zone = get_delivery_zone!(shop, zone_id)

        if Shops.delivery_point_within_zone?(%Shop{delivery_zone: zone.boundary}, lat, lng) do
          {:ok, zone, lat, lng}
        else
          {:error, :delivery_point_outside_zone}
        end

      is_nil(delivery_point) or String.trim(to_string(delivery_point)) == "" ->
        # Use the zone's centroid when no delivery address is provided
        zone = get_delivery_zone!(shop, zone_id)

        case calculate_zone_centroid(zone.boundary) do
          {:ok, centroid_lat, centroid_lng} ->
            {:ok, zone, centroid_lat, centroid_lng}

          {:error, _reason} ->
            {:error, :unresolved_delivery_point}
        end

      true ->
        zone = get_delivery_zone!(shop, zone_id)

        with {:ok, lat, lng} <- geocode_delivery_point(shop, zone, delivery_point),
             true <-
               Shops.delivery_point_within_zone?(%Shop{delivery_zone: zone.boundary}, lat, lng) do
          {:ok, zone, lat, lng}
        else
          false ->
            {:error, :delivery_point_outside_zone}

          {:error, :unresolved_delivery_point} ->
            # Fallback to zone centroid if geocoding fails
            case calculate_zone_centroid(zone.boundary) do
              {:ok, centroid_lat, centroid_lng} ->
                {:ok, zone, centroid_lat, centroid_lng}

              {:error, _reason} ->
                {:error, :unresolved_delivery_point}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp calculate_zone_centroid(%{"type" => "Polygon", "coordinates" => [outer_ring | _]})
       when is_list(outer_ring) do
    # Calculate the centroid by averaging all vertices in the outer ring
    # GeoJSON coordinates are [lng, lat]
    {sum_lng, sum_lat, count} =
      Enum.reduce(outer_ring, {0.0, 0.0, 0}, fn [lng, lat], {sum_lng, sum_lat, count} ->
        {sum_lng + lng, sum_lat + lat, count + 1}
      end)

    if count > 0 do
      centroid_lng = sum_lng / count
      centroid_lat = sum_lat / count
      {:ok, centroid_lat, centroid_lng}
    else
      {:error, :empty_boundary}
    end
  end

  defp calculate_zone_centroid(_), do: {:error, :invalid_boundary}

  defp geocode_delivery_point(%Shop{} = shop, zone, delivery_point) do
    query =
      [delivery_point, zone.name, shop.city, shop.country]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(", ")

    with {:ok, response} <-
           Req.get("https://nominatim.openstreetmap.org/search",
             params: %{q: query, format: "jsonv2", limit: 1},
             headers: [{"user-agent", "smart-kiosk/1.0"}]
           ),
         [%{"lat" => lat, "lon" => lng} | _] <- response.body,
         {lat, ""} <- Float.parse(to_string(lat)),
         {lng, ""} <- Float.parse(to_string(lng)) do
      {:ok, lat, lng}
    else
      _ -> {:error, :unresolved_delivery_point}
    end
  end
end
