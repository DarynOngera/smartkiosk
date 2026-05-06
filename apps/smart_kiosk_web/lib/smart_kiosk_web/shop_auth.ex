defmodule SmartKioskWeb.ShopAuth do
  @moduledoc """
  LiveView `on_mount` hook that loads the current user's shop and enforces
  that they belong to one before accessing merchant-dashboard routes.

  Add to a `live_session` block:

      on_mount: [
        {SmartKioskWeb.UserAuth, :ensure_authenticated},
        SmartKioskWeb.ShopAuth
      ]
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]

  use SmartKioskWeb, :verified_routes

  alias SmartKioskCore.Accounts

  @doc """
  Loads `current_shop` from the already-assigned `current_user`.

  Halts with a redirect to `/` if the user has no associated shop
  (e.g. a platform_admin accidentally hitting a merchant route).
  """
  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_user

    case Accounts.get_shop_for_user(user) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "No shop associated with your account.")
          |> redirect(to: ~p"/")

        {:halt, socket}

      shop ->
        {:cont, assign(socket, :current_shop, shop)}
    end
  end

  # Allow `on_mount: SmartKioskWeb.ShopAuth` shorthand (no atom given).
  def on_mount(atom, params, session, socket) when is_atom(atom) do
    on_mount(:default, params, session, socket)
  end
end
