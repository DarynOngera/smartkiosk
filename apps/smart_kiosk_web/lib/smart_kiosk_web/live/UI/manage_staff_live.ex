defmodule SmartKioskWeb.UI.ManageStaffLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts
  alias SmartKioskCore.Schemas.User
  alias SmartKioskCore.Shops

  @tabs ~w(applications staff)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Staff")
     |> assign(:active_tab, :applications)
     |> assign(:tabs, @tabs)
     |> assign_staff_form(User.registration_changeset(%User{}, %{}))
     |> refresh_staff_data()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, :active_tab, tab_from_params(params))}
  end

  @impl true
  def handle_event("approve_application", %{"id" => application_id}, socket) do
    case Shops.approve_job_application(socket.assigns.current_shop, application_id) do
      {:ok, application} ->
        delivery_result =
          Accounts.deliver_job_acceptance_instructions(
            application.user,
            application.job_post,
            socket.assigns.current_shop,
            &url(~p"/job-invite/#{&1}")
          )

        flash_message =
          case delivery_result do
            {:ok, _email} ->
              "Application approved and account invite sent"

            {:error, _reason} ->
              "Application approved, but the account invite email could not be sent"
          end

        flash_kind =
          case delivery_result do
            {:ok, _email} -> :info
            {:error, _reason} -> :error
          end

        {:noreply,
         socket
         |> refresh_staff_data()
         |> put_flash(flash_kind, flash_message)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not approve application")}
    end
  end

  def handle_event("reject_application", %{"id" => application_id}, socket) do
    case Shops.reject_job_application(socket.assigns.current_shop, application_id) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> refresh_staff_data()
         |> put_flash(:info, "Application rejected")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not reject application")}
    end
  end

  def handle_event("validate_staff", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_staff_form(socket, changeset)}
  end

  def handle_event("save_staff", %{"user" => user_params}, socket) do
    case Shops.register_shop_user(socket.assigns.current_shop, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign_staff_form(User.registration_changeset(%User{}, %{}))
         |> refresh_staff_data()
         |> put_flash(:info, "Staff member added")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_staff_form(socket, Map.put(changeset, :action, :insert))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not add staff member")}
    end
  end

  defp refresh_staff_data(socket) do
    shop = socket.assigns.current_shop

    socket
    |> assign(:job_applications, Shops.list_job_applications(shop))
    |> assign(:staff_members, Shops.list_shop_users(shop))
  end

  defp assign_staff_form(socket, changeset) do
    assign(socket, :staff_form, to_form(changeset))
  end

  defp application_title(%{job_post: %{title: title}}) when is_binary(title) and title != "",
    do: title

  defp application_title(_application), do: "General shop application"

  defp application_role_label(%{job_post: %{role: role}}) when not is_nil(role),
    do: role |> to_string() |> String.capitalize()

  defp application_role_label(%{user: %{role: role}}) when not is_nil(role),
    do: role |> to_string() |> String.capitalize()

  defp application_role_label(_application), do: "Staff"

  defp tab_from_params(%{"tab" => tab}) do
    case tab do
      "staff" -> :staff
      "applications" -> :applications
      _ -> :applications
    end
  end

  defp tab_from_params(_params), do: :applications
end
