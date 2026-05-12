defmodule SmartKioskWeb.UserSettingsLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Account Settings · SmartKiosk")
     |> assign(:tab, "profile")
     |> assign(
       :profile_form,
       to_form(SmartKioskCore.Schemas.User.profile_changeset(user, %{}), as: "profile")
     )
     |> assign(:email_form, to_form(%{"email" => user.email}))
     |> assign(:password_form, to_form(%{}, as: :password))}
  end

  def handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_profile", %{"profile" => params}, socket) do
    user = socket.assigns.current_user
    changeset = Accounts.update_user_profile(user, params)

    {:noreply,
     socket
     |> assign(:profile_form, to_form(changeset, as: "profile", action: :validate))}
  end

  def handle_event("save_profile", %{"profile" => params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_profile(user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully.")
         |> assign(
           :profile_form,
           to_form(SmartKioskCore.Schemas.User.profile_changeset(user, %{}), as: "profile")
         )}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:profile_form, to_form(changeset, as: "profile"))}
    end
  end

  def handle_event("validate_email", params, socket) do
    user = socket.assigns.current_user

    email_value =
      case params do
        %{"email" => %{} = nested} -> nested["email"]
        %{"email" => email} -> email
        %{"email" => _, "current_password" => _} -> params["email"]
      end

    changeset = Accounts.change_user_email(user, %{"email" => email_value})

    {:noreply,
     socket
     |> assign(:email_form, to_form(changeset, as: "email", action: :validate))}
  end

  def handle_event("save_email", params, socket) do
    user = socket.assigns.current_user

    {email_value, password} =
      case params do
        %{"email" => %{} = nested} ->
          {nested["email"], nested["current_password"] || ""}

        %{"email" => email, "current_password" => password} ->
          {email, password || ""}

        %{"email" => _, "current_password" => _} ->
          {params["email"], params["current_password"] || ""}
      end

    case Accounts.update_user_email(user, %{"email" => email_value}, password) do
      {:ok, :email_sent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Confirmation link sent to your new email address.")
         |> assign(:email_form, to_form(%{"email" => user.email}))}

      {:error, :invalid_password} ->
        {:noreply,
         socket
         |> put_flash(:error, "Incorrect password. Please enter your current password.")
         |> assign(:email_form, to_form(%{"email" => email_value}))}

      {:error, :no_change} ->
        {:noreply,
         socket
         |> put_flash(:error, "New email must be different from your current email.")
         |> assign(:email_form, to_form(%{"email" => user.email}))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:email_form, to_form(changeset, as: "email"))}
    end
  end

  def handle_event("validate_password", params, socket) do
    user = socket.assigns.current_user
    changeset = Accounts.change_user_password(user, params)

    {:noreply,
     socket
     |> assign(:password_form, to_form(changeset, as: "password", action: :validate))}
  end

  def handle_event("save_password", params, socket) do
    user = socket.assigns.current_user

    case Accounts.reset_user_password(user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully.")
         |> assign(:password_form, to_form(%{}, as: "password"))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(changeset, as: "password"))}
    end
  end

  def handle_event("confirm_email", %{"token" => token}, socket) do
    case Accounts.apply_user_email(socket.assigns.current_user, token) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email updated successfully.")
         |> push_navigate(to: ~p"/users/settings?tab=email")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Email change link is invalid or has expired.")
         |> push_navigate(to: ~p"/users/settings?tab=email")}
    end
  end
end
