defmodule SmartKioskWeb.UserRegistrationLive do
  @moduledoc """
  User registration form for new shop owners.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts
  alias SmartKioskCore.Schemas.{Shop, User}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto w-full max-w-md">
        <div class="text-center">
          <img class="mx-auto h-12 w-auto" src={~p"/images/logo.svg"} alt="SmartKiosk Logo" />
          <h2 class="mt-6 text-3xl font-extrabold text-gray-900">Create your account</h2>
          <p class="mt-2 text-sm text-gray-600">
            Start your 30-day free trial
          </p>
        </div>

        <.form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          class="mt-8 space-y-6"
        >
          <div class="-space-y-px rounded-md shadow-sm">
            <div>
              <.input
                field={@form[:full_name]}
                type="text"
                label="Full name"
                placeholder="Your full name"
                required
                class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
              />
            </div>
            <div>
              <.input
                field={@form[:email]}
                type="email"
                label="Email address"
                placeholder="Email address"
                required
                class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
              />
            </div>
            <div>
              <.input
                field={@form[:phone]}
                type="tel"
                label="Phone number"
                placeholder="+254 712 345 678"
                required
                class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
              />
            </div>
            <div>
              <.input
                field={@form[:shop_name]}
                type="text"
                label="Shop name"
                placeholder="Your shop name"
                required
                class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
              />
            </div>
            <div>
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                placeholder="Password"
                required
                class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              phx-disable-with="Creating account..."
              class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Create account
            </button>
          </div>
        </.form>

        <div class="text-center">
          <p class="text-sm text-gray-600">
            Already have an account?
            <a href={~p"/login"} class="font-medium text-indigo-600 hover:text-indigo-500">
              Sign in
            </a>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_registration(%{})
    {:ok, assign(socket, form: to_form(changeset, as: :registration))}
  end

  def handle_event("validate", params, socket) do
    registration_params = normalize_registration_params(params)
    changeset = Accounts.change_registration(registration_params)
    {:noreply, assign(socket, form: to_form(changeset, as: :registration, action: :validate))}
  end

  def handle_event("save", params, socket) do
    registration_params = normalize_registration_params(params)

    shop_attrs =
      registration_params
      |> Map.take(["shop_name", "phone"])
      |> Map.new(fn
        {"shop_name", value} -> {:name, value}
        {"phone", value} -> {:phone, value}
      end)

    user_attrs = Map.take(registration_params, ["full_name", "email", "password"])

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
    params["registration"] || params["shop"] || %{}
  end

  defp merge_registration_errors(registration_changeset, %Ecto.Changeset{} = error_changeset) do
    Enum.reduce(error_changeset.errors, registration_changeset, fn {field, {message, opts}}, changeset ->
      mapped_field = map_registration_error_field(error_changeset.data, field)

      if is_nil(mapped_field) do
        Ecto.Changeset.add_error(changeset, :base, message, opts)
      else
        Ecto.Changeset.add_error(changeset, mapped_field, message, opts)
      end
    end)
  end

  defp map_registration_error_field(%Shop{}, :name), do: :shop_name
  defp map_registration_error_field(%Shop{}, :slug), do: :shop_name
  defp map_registration_error_field(%Shop{}, :phone), do: :phone
  defp map_registration_error_field(%User{}, field) when field in [:full_name, :email, :password], do: field
  defp map_registration_error_field(_data, field) when field in [:full_name, :email, :phone, :password, :shop_name], do: field
  defp map_registration_error_field(_data, :base), do: :base
  defp map_registration_error_field(_data, _field), do: nil
end
