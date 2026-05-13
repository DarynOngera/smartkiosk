defmodule SmartKioskCore.Shops do
  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Role, Shop, Subscription, User, UserRole, UserToken}

  def change_registration(attrs \\ %{}) do
    types = %{
      full_name: :string,
      email: :string,
      password: :string,
      phone: :string,
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
      {:ok, %{shop: shop, user: user}} -> {:ok, shop, user}
      {:error, _step, changeset, _changes} -> {:error, changeset}
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
      {:ok, %{shop: shop, updated_user: user}} -> {:ok, shop, user}
      {:error, _step, changeset, _changes} -> {:error, changeset}
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
  end

  @doc "Lists all shops."
  def list_shops do
    Repo.all(Shop)
  end

  # get shop by the id

  def get_shop!(id) do
    Repo.get_by(Shop, id: id)
  end

  @doc "Gets a shop by name."
  def get_shop_by_name(name) when is_binary(name) do
    Repo.get_by(Shop, name: name)
  end

  @doc "Gets the shop for a given user."
  def get_shop_for_user(%User{shop_id: nil}), do: nil
  def get_shop_for_user(%User{shop_id: shop_id}), do: Repo.get(Shop, shop_id)

  @spec get_pending_status() :: any()
  @doc "Gets a shop by slug (used for public storefront URLs)."
  def get_shop_by_slug(slug), do: Repo.get_by(Shop, slug: slug, status: :active)

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
  end

  # reget the status
  def reject_shop(%Shop{} = shop) do
    shop
    |> Ecto.Changeset.change(status: :suspended)
    |> Repo.update()
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

  defp unwrap_or_rollback({:ok, value}), do: value
  defp unwrap_or_rollback({:error, reason}), do: Repo.rollback(reason)
  defp wrap_with_user(%User{} = user), do: {user, nil}
  defp wrap_with_user(nil), do: {nil, nil}

  defp verify_source_user(user, _token) do
    {:ok, user}
  end
end
