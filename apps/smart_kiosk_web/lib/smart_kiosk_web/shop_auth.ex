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
  alias SmartKioskCore.Authorization

  @doc """
  LiveView mount hooks for shop-related authentication and context.

  ## Hooks

    * `:default` (or no atom) - Loads `current_shop` and `permissions` for the user.
    * `:require_shop` - Ensures the user has an associated shop; redirects otherwise.
  """
  def on_mount(name, params, session, socket)

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_user

    case Accounts.get_shop_for_user(user) do
      nil ->
        {:cont,
         socket
         |> assign(:current_shop, nil)
         |> assign(:permissions, MapSet.new())}

      shop ->
        permissions = Authorization.list_permissions(user, shop)

        {:cont,
         socket
         |> assign(:current_shop, shop)
         |> assign(:permissions, permissions)}
    end
  end

  def on_mount(:require_shop, _params, _session, socket) do
    if socket.assigns[:current_shop] do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must have a shop to access this page.")
        |> redirect(to: ~p"/dashboard")

      {:halt, socket}
    end
  end

  # Allow `on_mount: SmartKioskWeb.ShopAuth` shorthand (no atom given).
  def on_mount(atom, params, session, socket) when is_atom(atom) do
    on_mount(:default, params, session, socket)
  end
end
