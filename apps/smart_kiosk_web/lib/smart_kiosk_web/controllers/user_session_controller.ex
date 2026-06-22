defmodule SmartKioskWeb.UserSessionController do
  use SmartKioskWeb, :controller

  alias SmartKioskCore.Accounts
  alias SmartKioskWeb.UserAuth
  import Phoenix.Controller  # for redirect/2
# lib/smart_kiosk_web/controllers/user_session_controller.ex

def create(conn, %{"email" => email, "password" => password} = _params) do
  user = Accounts.get_user_by_email_and_password(email, password)

  if user do
    redirect_path = if user.role == :cashier, do: ~p"/pos", else: ~p"/dashboard"

    conn
    |> put_flash(:info, "Welcome back!")
    |> UserAuth.log_in_user(user, redirect_to: redirect_path)
  else
    conn
    |> put_flash(:error, "Invalid email or password")
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/login")
  end
end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
