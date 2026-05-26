defmodule SmartKioskCore.Shops do
  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Role, Shop, Subscription, User, UserRole}

  def change_registration(attrs \\ %{}) do
    types = %{
      full_name: :string,
      email: :string,
      password: :string,
      phone: :string,
      plan: :string,
      shop_category: :string,
      address: :string,
      city: :string
    }

    {%{}, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([:full_name, :email, :password, :phone, :shop_category])
    |> Ecto.Changeset.validate_length(:password, min: 12, max: 72)
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_format(:phone, ~r/^[+]?[\d\s\-\(\)]+$/,
      message: "must be a valid phone number"
    )
    |> Ecto.Changeset.validate_inclusion(
      :shop_category,
      Enum.map(Shop.categories(), &to_string/1)
    )
    |> Ecto.Changeset.validate_inclusion(
      :plan,
      Enum.map(SmartKioskCore.Plans.list_plans(), & &1.slug)
    )
  end

  # ── Shop operations ───────────────────────────────────────────────────────────
  @doc "Creates a shop and assigns the given user as owner in a single transaction."
  def create_shop_for_user(%User{} = user, shop_attrs) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:shop, Shop.changeset(%Shop{owner_id: user.id}, shop_attrs))
      |> Ecto.Multi.run(:user, fn repo, %{shop: shop} ->
        user
        |> User.assign_to_shop_changeset(shop, :owner)
        |> repo.update()
      end)
      |> Ecto.Multi.run(:owner_role, fn repo, %{user: updated_user, shop: shop} ->
        assign_system_role(repo, updated_user, "owner", shop)
      end)
      |> Ecto.Multi.insert(:subscription, fn %{shop: shop} ->
        %Subscription{}
        |> Subscription.changeset(%{
          shop_id: shop.id,
          # Respect the shop's chosen plan; fall back to :kiosk if missing
          plan: shop.plan || :kiosk,
          status: :trialing,
          trial_ends_at: DateTime.add(DateTime.utc_now(), 30, :day) |> DateTime.truncate(:second)
        })
      end)

    case Repo.transaction(multi) do
      {:ok, %{shop: shop, user: user}} ->
        enqueue_search_indexing({:ok, shop}, "shop")
        {:ok, shop, user}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Registers a new shop owner and creates their shop in a single transaction.

  Accepts:
    - shop_attrs: %{name: "...", phone: "...", category: "..."}
    - user_attrs: %{full_name: "...", email: "...", password: "...", phone: "..."}

  Returns {:ok, shop, user} or {:error, changeset}.
  """
  def register_shop_owner(shop_attrs, user_attrs) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:user, fn _changes ->
        %User{role: :customer}
        |> User.registration_changeset(user_attrs)
      end)
      |> Ecto.Multi.insert(:shop, fn %{user: user} ->
        %Shop{owner_id: user.id}
        |> Shop.changeset(shop_attrs)
      end)
      |> Ecto.Multi.run(:updated_user, fn repo, %{user: user, shop: shop} ->
        user
        |> User.assign_to_shop_changeset(shop, :owner)
        |> repo.update()
      end)
      |> Ecto.Multi.run(:owner_role, fn repo, %{updated_user: user, shop: shop} ->
        assign_system_role(repo, user, "owner", shop)
      end)
      |> Ecto.Multi.insert(:subscription, fn %{shop: shop} ->
        %Subscription{}
        |> Subscription.changeset(%{
          shop_id: shop.id,
          plan: shop.plan || :kiosk,
          status: :trialing,
          trial_ends_at: DateTime.add(DateTime.utc_now(), 30, :day) |> DateTime.truncate(:second)
        })
      end)

    case Repo.transaction(multi) do
      {:ok, %{shop: shop, updated_user: user}} ->
        enqueue_search_indexing({:ok, shop}, "shop")
        {:ok, shop, user}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc "Registers a staff user under an existing shop."
  def register_shop_user(%Shop{} = shop, attrs) do
    Repo.transaction(fn ->
      user =
        %User{shop_id: shop.id, role: :staff}
        |> create_user(attrs)
        |> unwrap_or_rollback()

      assign_system_role(Repo, user, "staff", shop)
      |> unwrap_or_rollback()

      user
    end)
  end

  defp create_user(%User{} = user, attrs) do
    user
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates shop profile details."
  def update_shop(%Shop{} = shop, attrs) do
    shop
    |> Shop.changeset(attrs)
    |> Repo.update()
    |> tap(&enqueue_search_indexing(&1, "shop"))
  end

  @doc "Lists all shops."
  def list_shops do
    Repo.all(Shop)
  end

  @doc "Gets a shop by id."
  def get_shop(id) do
    Repo.get(Shop, id)
  end

  # get shop by the id

  def get_shop!(id) do
    Repo.get_by(Shop, id: id)
  end

  defp enqueue_search_indexing({:ok, %{id: _id} = shop}, "shop") do
    SmartKioskCore.Search.index_shop(shop)
  end

  defp enqueue_search_indexing({:ok, shop, _user}, "shop") do
    SmartKioskCore.Search.index_shop(shop)
  end

  defp enqueue_search_indexing(_, _), do: :ok

  @doc "Gets a shop by name."
  def get_shop_by_name(name) when is_binary(name) do
    Repo.get_by(Shop, name: name)
  end

  @doc "Gets the shop for a given user."
  def get_shop_for_user(%User{shop_id: nil}), do: nil
  def get_shop_for_user(%User{shop_id: shop_id}), do: Repo.get(Shop, shop_id)

  @doc """
  Returns true if the given `%Geo.Point{}` (lon, lat) lies inside the shop's
  `delivery_zone` geometry. Uses PostGIS `ST_Contains`. Returns false if the
  shop doesn't exist or has no zone.
  """
  def inside_delivery_zone?(shop_id, %Geo.Point{} = point) do
    {lng, lat} =
      case point.coordinates do
        {x, y} -> {x, y}
        [x, y] -> {x, y}
        _ -> {nil, nil}
      end

    case {lng, lat} do
      {nil, nil} ->
        false

      {lng, lat} ->
        query =
          from(s in Shop,
            where:
              s.id == ^shop_id and
                fragment(
                  "ST_Contains(?, ST_SetSRID(ST_Point(?, ?), 4326))",
                  s.delivery_zone,
                  ^lng,
                  ^lat
                ),
            select: s.id,
            limit: 1
          )

        case Repo.one(query) do
          nil -> false
          _ -> true
        end
    end
  end

  @doc """
  Returns true when a delivery point lies inside the shop's saved delivery zone.

  Supports the JSONB GeoJSON fallback used when PostGIS is unavailable and the
  geometry-backed shape used when PostGIS is enabled.
  """
  def delivery_point_within_zone?(%Shop{} = shop, lat, lng)
      when is_number(lat) and is_number(lng) do
    case shop.delivery_zone do
      nil ->
        false

      %Geo.Polygon{coordinates: [outer_ring | _]} ->
        point_in_ring?(outer_ring, lng, lat)

      %Geo.MultiPolygon{coordinates: [polygon | _]} ->
        polygon |> List.first() |> point_in_ring?(lng, lat)

      %{"type" => "Polygon", "coordinates" => [outer_ring | _]} when is_list(outer_ring) ->
        point_in_ring?(outer_ring, lng, lat)

      %{"type" => "MultiPolygon", "coordinates" => [polygon | _]} when is_list(polygon) ->
        polygon |> List.first() |> point_in_ring?(lng, lat)

      _ ->
        false
    end
  end

  def delivery_point_within_zone?(_shop, _lat, _lng), do: false

  @spec get_pending_status() :: any()
  @doc "Gets a shop by slug (used for public storefront URLs)."
  def get_shop_by_slug(slug), do: Repo.get_by(Shop, slug: slug, status: :active)

  @doc "Searches shops by name or description."
  def search_shops(query) do
    term = "%#{query}%"

    from(s in Shop,
      where: ilike(s.name, ^term),
      where: s.status == :active,
      order_by: [desc: s.inserted_at]
    )
    |> Repo.all()
  end

  defp point_in_ring?(ring, point_x, point_y) when is_list(ring) do
    vertices =
      Enum.map(ring, fn
        [x, y] -> {x, y}
        %{"x" => x, "y" => y} -> {x, y}
        _ -> {nil, nil}
      end)
      |> Enum.reject(&match?({nil, nil}, &1))

    point_in_polygon?(vertices, {point_x, point_y})
  rescue
    _ -> false
  end

  defp point_in_polygon?(vertices, {px, py}) when is_list(vertices) do
    vertex_count = length(vertices)

    vertices
    |> Enum.with_index()
    |> Enum.reduce(false, fn {{x_i, y_i}, index}, acc ->
      {x_j, y_j} = Enum.at(vertices, rem(index + 1, vertex_count))

      intersects =
        y_i > py != y_j > py and
          px < (x_j - x_i) * (py - y_i) / (y_j - y_i + 0.0) + x_i

      if intersects, do: not acc, else: acc
    end)
  end

  # =================for admin side =========================
  # check for status:pending review
  def get_pending_status do
    Shop
    |> where([s], s.status == :pending_review)
    |> Repo.all()
  end

  # approve the shop
  def approve_shop(%Shop{} = shop) do
    shop
    |> Ecto.Changeset.change(status: :active)
    |> Repo.update()
    |> tap(&enqueue_search_indexing(&1, "shop"))
  end

  # reget the status
  def reject_shop(%Shop{} = shop) do
    shop
    |> Ecto.Changeset.change(status: :suspended)
    |> Repo.update()
    |> tap(&enqueue_search_indexing(&1, "shop"))
  end

  # defp create_initial_subscription(shop) do
  #   %SmartKioskCore.Schemas.Subscription{}
  #   |> SmartKioskCore.Schemas.Subscription.changeset(%{
  #     shop_id: shop.id,
  #     plan: :kiosk,
  #     status: :trialing,
  #     trial_ends_at: DateTime.add(DateTime.utc_now(), 30, :day) |> DateTime.truncate(:second)
  #   })
  #   |> Repo.insert()
  # end

  # =================HELPERS=================
  @doc "Lists all staff for a given shop."
  def list_shop_users(%Shop{id: shop_id}) do
    from(u in User, where: u.shop_id == ^shop_id, order_by: [asc: u.role, asc: u.full_name])
    |> Repo.all()
  end

  defp assign_system_role(repo, %User{id: user_id}, role_slug, shop) when is_binary(role_slug) do
    case repo.get_by(Role, slug: role_slug) do
      %Role{id: role_id} ->
        %UserRole{}
        |> UserRole.changeset(%{
          user_id: user_id,
          role_id: role_id,
          shop_id: shop && shop.id
        })
        |> repo.insert(on_conflict: :nothing)

      nil ->
        %UserRole{}
        |> UserRole.changeset(%{})
        |> Ecto.Changeset.add_error(:role_id, "missing system role #{role_slug}")
        |> then(&{:error, &1})
    end
  end

  @doc """
  Registers a new rider user and their profile under a specific shop.
  Enforces plan-based rider limits.
  """
  def register_rider(%Shop{} = shop, user_attrs, rider_attrs) do
    # 1. Enforce plan limits
    plan_slug = shop.plan |> SmartKioskCore.Schemas.Shop.canonical_plan() |> Atom.to_string()
    plan = SmartKioskCore.Plans.list_plans() |> Enum.find(fn p -> p.slug == plan_slug end)
    max_allowed = (plan && plan.max_riders) || 1

    current_count = count_riders(shop)

    if current_count >= max_allowed do
      %SmartKioskCore.Schemas.Rider{}
      |> SmartKioskCore.Schemas.Rider.changeset(%{})
      |> Ecto.Changeset.add_error(:base, "Rider limit reached for your plan (#{max_allowed})")
      |> then(&{:error, &1})
    else
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:user, fn _changes ->
          %User{role: :rider, shop_id: shop.id}
          |> User.registration_changeset(user_attrs)
        end)
        |> Ecto.Multi.insert(:rider, fn %{user: user} ->
          %SmartKioskCore.Schemas.Rider{user_id: user.id}
          |> SmartKioskCore.Schemas.Rider.changeset(rider_attrs)
        end)
        |> Ecto.Multi.run(:system_role, fn repo, %{user: user} ->
          assign_system_role(repo, user, "rider", shop)
        end)

      case Repo.transaction(multi) do
        {:ok, %{user: user, rider: rider}} -> {:ok, user, rider}
        {:error, _step, changeset, _changes} -> {:error, changeset}
      end
    end
  end

  @doc "Counts active riders for a shop."
  def count_riders(%Shop{id: shop_id}) do
    from(r in SmartKioskCore.Schemas.Rider,
      join: u in User,
      on: r.user_id == u.id,
      where: u.shop_id == ^shop_id
    )
    |> Repo.aggregate(:count, :id)
  end

  defp unwrap_or_rollback({:ok, value}), do: value
  defp unwrap_or_rollback({:error, reason}), do: Repo.rollback(reason)
  # defp wrap_with_user(%User{} = user), do: {user, nil}
  # defp wrap_with_user(nil), do: {nil, nil}

  # defp verify_source_user(user, _token) do
  #   {:ok, user}
  # end
end
