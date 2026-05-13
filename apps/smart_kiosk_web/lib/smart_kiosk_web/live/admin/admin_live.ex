defmodule SmartKioskWeb.AdminLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Shops

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    current_shop = current_user && Shops.get_shop_for_user(current_user)

    pending_approval = Shops.get_pending_status()
    shops = Shops.list_shops()

    # Calculate stats
    total_shops = length(shops)
    active_shops = Enum.count(shops, fn s -> s.status == :active end)
    pending_count = length(pending_approval)

    # Placeholder data for features not yet implemented
    # TODO: Replace with actual queries when schemas are created
    # TODO: Accounts.list_riders()
    riders = []
    # TODO: Accounts.list_customer_reports()
    customer_reports = []
    # TODO: Accounts.list_pickup_points()
    pickup_points = []
    # TODO: Accounts.list_hotspots()
    hotspots = []

    {:ok,
     socket
     |> assign(:current_shop, current_shop)
     |> assign(:shops, shops)
     |> assign(:pending, pending_approval)
     |> assign(:total_shops, total_shops)
     |> assign(:active_shops, active_shops)
     |> assign(:pending_count, pending_count)
     |> assign(:riders, riders)
     |> assign(:customer_reports, customer_reports)
     |> assign(:pickup_points, pickup_points)
     |> assign(:hotspots, hotspots)
     |> assign(:page_title, "Admin Dashboard")}
  end

  @impl true
  def handle_event("approve_shop", %{"shop_id" => shop_id}, socket) do
    shop = Accounts.get_shop!(shop_id)

    case Accounts.approve_shop(shop) do
      {:ok, _shop} ->
        pending_approval = Accounts.get_pending_status()
        shops = Accounts.list_shops()

        {:noreply,
         socket
         |> assign(:shops, shops)
         |> assign(:pending, pending_approval)
         |> assign(:total_shops, length(shops))
         |> assign(:active_shops, Enum.count(shops, fn s -> s.status == :active end))
         |> assign(:pending_count, length(pending_approval))
         |> put_flash(:info, "Shop approved successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve shop")}
    end
  end

  @impl true
  def handle_event("reject_shop", %{"shop_id" => shop_id}, socket) do
    shop = Accounts.get_shop!(shop_id)

    case Accounts.reject_shop(shop) do
      {:ok, _shop} ->
        pending_approval = Accounts.get_pending_status()
        shops = Accounts.list_shops()

        {:noreply,
         socket
         |> assign(:shops, shops)
         |> assign(:pending, pending_approval)
         |> assign(:pending_count, length(pending_approval))
         |> put_flash(:info, "Shop rejected")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reject shop")}
    end
  end
end
