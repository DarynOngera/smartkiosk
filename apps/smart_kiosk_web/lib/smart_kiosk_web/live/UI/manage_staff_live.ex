defmodule SmartKioskWeb.UI.ManageStaffLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Schemas.User
  alias SmartKioskCore.Shops

  @tabs ~w(riders staff)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Staff")
     |> assign(:active_tab, :riders)
     |> assign(:tabs, @tabs)
     |> assign_staff_form(User.registration_changeset(%User{}, %{}))
     |> refresh_staff_data()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, :active_tab, tab_from_params(params))}
  end

  @impl true
  def handle_event("approve_rider", %{"id" => rider_id}, socket) do
    case Shops.approve_rider_application(socket.assigns.current_shop, rider_id) do
      {:ok, _rider} ->
        {:noreply,
         socket
         |> refresh_staff_data()
         |> put_flash(:info, "Rider application approved")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not approve rider application")}
    end
  end

  def handle_event("reject_rider", %{"id" => rider_id}, socket) do
    case Shops.reject_rider_application(socket.assigns.current_shop, rider_id) do
      {:ok, _rider} ->
        {:noreply,
         socket
         |> refresh_staff_data()
         |> put_flash(:info, "Rider application rejected")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not reject rider application")}
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
    |> assign(:rider_applications, Shops.list_rider_applications(shop))
    |> assign(:staff_members, Shops.list_shop_users(shop))
  end

  defp assign_staff_form(socket, changeset) do
    assign(socket, :staff_form, to_form(changeset))
  end

  defp tab_from_params(%{"tab" => tab}) do
    case tab do
      "staff" -> :staff
      "riders" -> :riders
      _ -> :riders
    end
  end

  defp tab_from_params(_params), do: :riders
end
