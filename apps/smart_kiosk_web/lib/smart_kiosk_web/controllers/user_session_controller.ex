defmodule SmartKioskWeb.UserSessionController do
  use SmartKioskWeb, :controller

  alias SmartKioskCore.Accounts

  def create(conn, %{"email" => email, "password" => password} = _params) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %SmartKioskCore.Schemas.User{} = user ->
        token = Accounts.generate_user_session_token(user)

        conn =
          conn
          |> put_session(:user_token, token)
          |> configure_session(renew: true)

        # Redirect to the stored return path (if any), otherwise home
        user_return_to = get_session(conn, :user_return_to)

        conn
        |> put_flash(:info, "Signed in successfully")
        |> redirect(to: user_return_to || "/")

      _ ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn =
      case get_session(conn, :user_token) do
        nil -> conn
        token ->
          Accounts.delete_user_session_token(token)
          configure_session(conn, drop: true)
      end

    conn
    |> put_flash(:info, "Logged out")
    |> redirect(to: "/")
  end
end
