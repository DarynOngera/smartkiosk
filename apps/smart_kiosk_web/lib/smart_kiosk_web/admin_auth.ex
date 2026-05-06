defmodule SmartKioskWeb.AdminAuth do
  @moduledoc """
  LiveView `on_mount` hook that enforces platform-admin access for the
  `/admin/*` live session.

  The `UserAuth.ensure_authenticated` hook must run first (it is listed
  before this module in the router's `on_mount` list) so `current_user`
  is already in the socket assigns by the time this hook executes.

  Usage in the router:

      live_session :admin,
        on_mount: [
          {SmartKioskWeb.UserAuth, :ensure_authenticated},
          SmartKioskWeb.AdminAuth
        ] do
        ...
      end
  """

  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]

  use SmartKioskWeb, :verified_routes

  @doc "Halts with 403-equivalent redirect unless the user is a platform_admin."
  def on_mount(:default, _params, _session, socket) do
    case socket.assigns.current_user do
      %{role: :platform_admin} ->
        {:cont, socket}

      _ ->
        socket =
          socket
          |> put_flash(:error, "You are not authorised to access this area.")
          |> redirect(to: ~p"/")

        {:halt, socket}
    end
  end

  def on_mount(atom, params, session, socket) when is_atom(atom) do
    on_mount(:default, params, session, socket)
  end
end
