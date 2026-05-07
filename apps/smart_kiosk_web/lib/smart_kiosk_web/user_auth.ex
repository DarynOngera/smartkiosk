defmodule SmartKioskWeb.UserAuth do
  @moduledoc """
  Plugs and LiveView mount hooks for user authentication.

  Provides:
    - `fetch_current_user/2`       — populates `conn.assigns.current_user`
    - `require_authenticated_user/2` — redirects to login if not signed in
    - `redirect_if_user_is_authenticated/2` — redirects away from guest-only pages
    - `require_platform_admin/2`   — 403 unless the user has role :platform_admin
    - LiveView `on_mount` callbacks with the same names (atom keys)
  """

  use SmartKioskWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias SmartKioskCore.Accounts

  # ---------------------------------------------------------------------------
  # Session key
  # ---------------------------------------------------------------------------

  @session_key "_smart_kiosk_web_user_token"

  # ---------------------------------------------------------------------------
  # Plugs
  # ---------------------------------------------------------------------------

  @doc "Reads the session token and loads the current user into assigns."
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    current_user =
      user_token && Accounts.get_user_by_session_token(user_token)

    assign(conn, :current_user, current_user)
  end

  @doc "Redirects authenticated users away from guest-only pages (login, register)."
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc "Requires the user to be signed in; redirects to login otherwise."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must sign in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc "Requires the user to have the platform:manage_shops permission."
  def require_platform_admin(conn, _opts) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must sign in to access this page.")
        |> redirect(to: ~p"/login")
        |> halt()

      Canada.Can.can?(user, :manage_shops, nil) ->
        conn

      true ->
        conn
        |> put_status(:forbidden)
        |> put_view(html: SmartKioskWeb.ErrorHTML)
        |> render(:"403")
        |> halt()
    end
  end

  # ---------------------------------------------------------------------------
  # LiveView on_mount hooks
  # ---------------------------------------------------------------------------

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must sign in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def on_mount(:current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  # ---------------------------------------------------------------------------
  # Session helpers (used by UserSessionController)
  # ---------------------------------------------------------------------------

  @doc "Logs in a user by writing the session token to the cookie."
  def log_in_user(conn, user, _params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  @doc "Logs out the current user and deletes the session token."
  def log_out_user(conn) do
    user_token = get_session(conn, @session_key)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      SmartKioskWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session[@session_key] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, @session_key) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [])
      {nil, conn}
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(@session_key, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp signed_in_path(_conn_or_socket), do: ~p"/dashboard"
end
