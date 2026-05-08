defmodule SmartKioskWeb.UserRegistrationLive do
  @moduledoc """
  Modern styled registration page for new shop owners.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts
  alias SmartKioskCore.Schemas.User

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-[80vh] flex items-center justify-center px-4 py-12">
        <div class="card bg-base-100 shadow-xl w-full max-w-lg">
          <div class="card-body space-y-6">
            <%!-- Logo & Header --%>
            <div class="text-center space-y-2">
              <div class="avatar placeholder mx-auto">
                <div class="bg-primary text-primary-content w-16 rounded-xl">
                  <span class="text-2xl font-bold">SK</span>
                </div>
              </div>
              <h2 class="card-title justify-center text-2xl font-bold">Create your account</h2>
              <p class="text-base-content/70">Start your 30-day free trial today</p>
            </div>

            <%!-- Registration Form --%>
            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <%!-- Full Name --%>
              <div class="form-control">
                <label class="label" for="full_name">
                  <span class="label-text font-medium">Full Name</span>
                </label>
                <label class={[
                  "input input-bordered flex items-center gap-2",
                  @form[:full_name].errors != [] && "input-error",
                  @form[:full_name].errors == [] && @form[:full_name].value && "input-success"
                ]}>
                  <.icon name="hero-user" class="w-4 h-4 text-base-content/50" />
                  <input
                    type="text"
                    id="full_name"
                    name={@form[:full_name].name}
                    value={@form[:full_name].value}
                    placeholder="John Doe"
                    required
                    class="grow bg-transparent border-none focus:outline-none"
                  />
                </label>
                <.error :for={error <- @form[:full_name].errors}>{error}</.error>
              </div>

              <%!-- Email --%>
              <div class="form-control">
                <label class="label" for="email">
                  <span class="label-text font-medium">Email</span>
                </label>
                <label class={[
                  "input input-bordered flex items-center gap-2",
                  @form[:email].errors != [] && "input-error",
                  @form[:email].errors == [] && @form[:email].value && "input-success"
                ]}>
                  <.icon name="hero-envelope" class="w-4 h-4 text-base-content/50" />
                  <input
                    type="email"
                    id="email"
                    name={@form[:email].name}
                    value={@form[:email].value}
                    placeholder="you@example.com"
                    required
                    class="grow bg-transparent border-none focus:outline-none"
                  />
                </label>
                <.error :for={error <- @form[:email].errors}>{error}</.error>
              </div>

              <%!-- Phone --%>
              <div class="form-control">
                <label class="label" for="phone">
                  <span class="label-text font-medium">Phone Number</span>
                </label>
                <label class={[
                  "input input-bordered flex items-center gap-2",
                  @form[:phone].errors != [] && "input-error",
                  @form[:phone].errors == [] && @form[:phone].value && "input-success"
                ]}>
                  <.icon name="hero-phone" class="w-4 h-4 text-base-content/50" />
                  <input
                    type="tel"
                    id="phone"
                    name={@form[:phone].name}
                    value={@form[:phone].value}
                    placeholder="+254 712 345 678"
                    required
                    class="grow bg-transparent border-none focus:outline-none"
                  />
                </label>
                <.error :for={error <- @form[:phone].errors}>{error}</.error>
              </div>

              <%!-- Shop Category --%>
              <div class="form-control">
                <label class="label" for="shop_category">
                  <span class="label-text font-medium">Shop Category</span>
                </label>
                <label class={[
                  "input input-bordered flex items-center gap-2",
                  @form[:shop_category].errors != [] && "input-error",
                  @form[:shop_category].errors == [] && @form[:shop_category].value && "input-success"
                ]}>
                  <.icon name="hero-tag" class="w-4 h-4 text-base-content/50" />
                  <select
                    id="shop_category"
                    name={@form[:shop_category].name}
                    required
                    class="grow bg-transparent border-none focus:outline-none"
                  >
                    <option value="" disabled selected={is_nil(@form[:shop_category].value)}>Select a category</option>
                    <%= for {cat, label} <- @category_options do %>
                      <option value={cat} selected={@form[:shop_category].value == cat}>{label}</option>
                    <% end %>
                  </select>
                </label>
                <.error :for={error <- @form[:shop_category].errors}>{error}</.error>
              </div>

              <%!-- Password --%>
              <div class="form-control">
                <label class="label" for="password">
                  <span class="label-text font-medium">Password</span>
                  <span class="label-text-alt text-base-content/50">Min 12 characters</span>
                </label>
                <label class={[
                  "input input-bordered flex items-center gap-2",
                  @form[:password].errors != [] && "input-error"
                ]}>
                  <.icon name="hero-lock-closed" class="w-4 h-4 text-base-content/50" />
                  <input
                    type="password"
                    id="password"
                    name={@form[:password].name}
                    value={@form[:password].value}
                    placeholder="••••••••••••"
                    required
                    minlength="12"
                    class="grow bg-transparent border-none focus:outline-none"
                  />
                </label>
                <.error :for={error <- @form[:password].errors}>{error}</.error>
              </div>

              <%!-- Submit Button --%>
              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="btn btn-primary w-full mt-6"
              >
                <.icon name="hero-user-plus" class="w-5 h-5" />
                Create account
              </button>
            </.form>

            <%!-- Divider --%>
            <div class="divider text-sm">or</div>

            <%!-- Sign In Link --%>
            <div class="text-center text-sm">
              <span class="text-base-content/70">Already have an account?</span>
              <a href={~p"/login"} class="link link-primary font-medium ml-1">
                Sign in
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_registration(%{})

    category_options =
      SmartKioskCore.Schemas.Shop.category_labels()
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)

    {:ok, assign(socket, form: to_form(changeset, as: :registration), category_options: category_options)}
  end

  def handle_event("validate", params, socket) do
    registration_params = normalize_registration_params(params)
    changeset = Accounts.change_registration(registration_params)
    {:noreply, assign(socket, form: to_form(changeset, as: :registration, action: :validate))}
  end

  def handle_event("save", params, socket) do
    registration_params = normalize_registration_params(params)

    shop_attrs = %{
      "name" => registration_params["full_name"] <> "'s Shop",
      "phone" => registration_params["phone"],
      "category" => registration_params["shop_category"],
      "address" => registration_params["address"] || "Nairobi",
      "city" => registration_params["city"] || "Nairobi",
      "country" => "KE"
    }

    user_attrs = Map.take(registration_params, ["full_name", "email", "password", "phone"])

    case Accounts.register_shop_owner(shop_attrs, user_attrs) do
      {:ok, _shop, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! Please check your email to confirm.")
         |> redirect(to: ~p"/login")}

      {:error, %Ecto.Changeset{} = error_changeset} ->
        changeset =
          registration_params
          |> Accounts.change_registration()
          |> merge_registration_errors(error_changeset)
        {:noreply, assign(socket, form: to_form(changeset, as: :registration, action: :insert))}
    end
  end

  defp normalize_registration_params(params) when is_map(params) do
    params["registration"] || %{}
  end

  defp merge_registration_errors(registration_changeset, %Ecto.Changeset{} = error_changeset) do
    Enum.reduce(error_changeset.errors, registration_changeset, fn {field, {message, opts}}, changeset ->
      mapped_field = map_error_field(field)
      Ecto.Changeset.add_error(changeset, mapped_field, message, opts)
    end)
  end

  defp map_error_field(:email), do: :email
  defp map_error_field(:full_name), do: :full_name
  defp map_error_field(:password), do: :password
  defp map_error_field(:name), do: :full_name
  defp map_error_field(:category), do: :shop_category
  defp map_error_field(:phone), do: :phone
  defp map_error_field(_), do: :base
end
