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

  # =============================================
  # THIS IS FOR THE CASHIER BUSINESS
  # ===================================

  def on_mount(:require_cashier_only, _params, _session, socket) do
    user = socket.assigns[:current_user]
    shop = socket.assigns[:current_shop]

    # Allow cashiers AND shop owners (anyone associated with a shop) to use the POS
    if user && (user.role == :cashier || shop != nil) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/dashboard")}
    end
  end

  def on_mount(:restrict_cashier, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.role == :cashier do
      # Cashier trying to access non‑POS page – redirect to POS
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/pos")}
    else
      {:cont, socket}
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

  def on_mount(:load_cart_count, _params, session, socket) do
    current_user = socket.assigns[:current_user]

    # Try to get session_id from session first (standard HTTP)
    session_id = session["session_id"]

    # If not in session, it might be in connect_params (WebSocket)
    session_id = session_id || (Phoenix.LiveView.get_connect_params(socket) || %{})["session_id"]

    cart_count =
      cond do
        current_user ->
          SmartKioskCore.Cart.get_user_cart_count(current_user)

        session_id ->
          SmartKioskCore.Cart.get_session_cart_count(session_id)

        true ->
          0
      end

    {:cont,
     socket
     |> Phoenix.Component.assign(:session_id, session_id)
     |> Phoenix.Component.assign(:cart_count, cart_count)}
  end

  # ---------------------------------------------------------------------------
  # Session helpers (used by UserSessionController)
  # ---------------------------------------------------------------------------

  @doc "Logs in a user by writing the session token to the cookie."
  def log_in_user(conn, user, opts \\ []) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)
    redirect_to = Keyword.get(opts, :redirect_to, user_return_to || signed_in_path(conn))

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> redirect(to: redirect_to)
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

  defp signed_in_path(conn_or_socket) do
    current_user =
      case conn_or_socket do
        %Plug.Conn{} = conn -> conn.assigns[:current_user]
        %Phoenix.LiveView.Socket{} = socket -> socket.assigns[:current_user]
        _ -> nil
      end

    if current_user && current_user.role == :cashier do
      ~p"/pos"
    else
      ~p"/dashboard"
    end
  end
end
