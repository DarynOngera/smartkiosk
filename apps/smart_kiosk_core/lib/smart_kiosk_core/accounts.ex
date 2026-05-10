defmodule SmartKioskCore.Accounts do
  @moduledoc """
  The Accounts context.

  Manages users, authentication tokens, and shop identity (registration,
  onboarding). This is the entry point for all auth-related operations.
  All password/token logic lives here — LiveView and controllers should
  only call this context, never touch schemas directly.
  """

  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{User, UserToken, Shop}

  # ── User queries ─────────────────────────────────────────────────────────────

  @doc "Gets all users."
  def list_users do
    Repo.all(User) |> Repo.preload(:shop)
  end

  @doc "Gets a user by email."
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc "Gets a user by email and password. Returns nil if credentials invalid."
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc "Gets a user by id. Raises if not found."
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Gets a user with their shop preloaded."
  def get_user_with_shop!(id) do
    User |> Repo.get!(id) |> Repo.preload(:shop)
  end

  # ── User registration ─────────────────────────────────────────────────────────

  @doc """
  Returns a changeset for the platform user registration form.

  This is used for LiveView validations and therefore does not hash passwords
  or hit the database to validate unique email on every keystroke.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    user
    |> User.registration_changeset(attrs, hash_password: false, validate_email: false)
    |> Ecto.Changeset.unique_constraint(:email)
  end

  @doc """
  Returns a changeset for the shop owner registration form.
  Includes both user and shop fields for validation.
  """
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

  @doc """
  Registers a new platform user (role: `:customer`, no shop).
  """
  def register_user(attrs) do
    %User{role: :customer}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

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
      |> Ecto.Multi.insert(:subscription, fn %{shop: shop} ->
        %SmartKioskCore.Schemas.Subscription{}
        |> SmartKioskCore.Schemas.Subscription.changeset(%{
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
        %User{role: :owner}
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
      |> Ecto.Multi.insert(:subscription, fn %{shop: shop} ->
        %SmartKioskCore.Schemas.Subscription{}
        |> SmartKioskCore.Schemas.Subscription.changeset(%{
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
  def register_shop_user(shop, attrs) do
    create_user(%User{shop_id: shop.id, role: :staff}, attrs)
  end

  defp create_user(%User{} = user, attrs) do
    user
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # ── Shop operations ───────────────────────────────────────────────────────────

  @doc "Updates shop profile details."
  def update_shop(%Shop{} = shop, attrs) do
    shop
    |> Shop.changeset(attrs)
    |> Repo.update()
  end

  # list shops
  def list_shops do
    Repo.all(Shop)
  end

  # get shop by the id
  def get_shop_by_name(name) when is_binary(name) do
    Repo.get_by(Shop, name: name)
  end

  @doc "Gets the shop for a given user."
  def get_shop_for_user(%User{shop_id: nil}), do: nil
  def get_shop_for_user(%User{shop_id: shop_id}), do: Repo.get(Shop, shop_id)

  @doc "Gets a shop by slug (used for public storefront URLs)."
  def get_shop_by_slug(slug), do: Repo.get_by(Shop, slug: slug, status: :active)

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

  # ── Session tokens ────────────────────────────────────────────────────────────

  @doc "Generates a session token. Returns the raw token (stored in browser cookie)."
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc "Gets the user from a session token. Returns nil if token is invalid/expired."
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc "Deletes a session token (log out)."
  def delete_user_session_token(token) do
    Repo.delete_all(from(t in UserToken, where: t.token == ^token and t.context == "session"))
    :ok
  end

  # ── Email confirmation ────────────────────────────────────────────────────────

  @doc "Delivers an email confirmation link to the user."
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)

      SmartKioskCore.UserNotifier.deliver_confirmation_instructions(
        user,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  @doc "Confirms a user's email via a token."
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(
      :tokens,
      from(t in UserToken,
        where: t.user_id == ^user.id and t.context == "confirm"
      )
    )
  end

  # ── Password reset ────────────────────────────────────────────────────────────

  @doc "Delivers a password reset email."
  def deliver_user_reset_password_instructions(%User{} = user, reset_url_fun)
      when is_function(reset_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    SmartKioskCore.UserNotifier.deliver_reset_password_instructions(
      user,
      reset_url_fun.(encoded_token)
    )
  end

  @doc "Gets the user from a reset password token."
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_reset_password_token_query(token),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc "Resets the user's password."
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(
      :tokens,
      from(t in UserToken,
        where: t.user_id == ^user.id and t.context != "session"
      )
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  # ── User profile ──────────────────────────────────────────────────────────────

  @doc "Updates user profile (name, phone, avatar)."
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc "Lists all staff for a given shop."
  def list_shop_users(%Shop{id: shop_id}) do
    from(u in User, where: u.shop_id == ^shop_id, order_by: [asc: u.role, asc: u.full_name])
    |> Repo.all()
  end
end
