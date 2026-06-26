defmodule SmartKioskWeb.AdminLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Shops
  alias SmartKioskCore.Accounts

  @default_page_size 10

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    current_shop = current_user && Shops.get_shop_for_user(current_user)

    shops_page = Shops.list_shops(page: 1, page_size: @default_page_size)
    pending_page = Shops.get_pending_status(page: 1, page_size: @default_page_size)

    total_shops = Shops.count_shops()
    active_shops = Shops.count_shops(status: :active)

    # Placeholder data for features not yet implemented
    # TODO: Replace with actual queries when schemas are created
    # TODO: Shops.list_riders()
    riders = Accounts.get_riders()
    cashiers = Accounts.get_cashiers()
    # TODO: Shops.list_customer_reports()
    customer_reports = []
    # TODO: Shops.list_pickup_points()
    pickup_points = []
    # TODO: Shops.list_hotspots()
    hotspots = []

    {:ok,
     socket
     |> assign(:current_shop, current_shop)
     |> assign(:shops, shops_page.entries)
     |> assign(:pending, pending_page.entries)
     |> assign(:total_shops, total_shops)
     |> assign(:active_shops, active_shops)
     |> assign(:pending_count, pending_page.total_entries)
     |> assign(:riders, riders)
     |> assign(:cashiers, cashiers)
     |> assign(:customer_reports, customer_reports)
     |> assign(:pickup_points, pickup_points)
     |> assign(:hotspots, hotspots)
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:cart_count, 0)}
  end

  @impl true
  def handle_event("approve_shop", %{"shop_id" => shop_id}, socket) do
    shop = Shops.get_shop!(shop_id)

    case Shops.approve_shop(shop) do
      {:ok, _shop} ->
        shops_page = Shops.list_shops(page: 1, page_size: @default_page_size)
        pending_page = Shops.get_pending_status(page: 1, page_size: @default_page_size)
        total_shops = Shops.count_shops()
        active_shops = Shops.count_shops(status: :active)

        {:noreply,
         socket
         |> assign(:shops, shops_page.entries)
         |> assign(:pending, pending_page.entries)
         |> assign(:total_shops, total_shops)
         |> assign(:active_shops, active_shops)
         |> assign(:pending_count, pending_page.total_entries)
         |> put_flash(:info, "Shop approved successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve shop")}
    end
  end

  @impl true
  def handle_event("reject_shop", %{"shop_id" => shop_id}, socket) do
    shop = Shops.get_shop!(shop_id)

    case Shops.reject_shop(shop) do
      {:ok, _shop} ->
        shops_page = Shops.list_shops(page: 1, page_size: @default_page_size)
        pending_page = Shops.get_pending_status(page: 1, page_size: @default_page_size)
        total_shops = Shops.count_shops()
        active_shops = Shops.count_shops(status: :active)

        {:noreply,
         socket
         |> assign(:shops, shops_page.entries)
         |> assign(:pending, pending_page.entries)
         |> assign(:total_shops, total_shops)
         |> assign(:active_shops, active_shops)
         |> assign(:pending_count, pending_page.total_entries)
         |> put_flash(:info, "Shop rejected")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reject shop")}
    end
  end
end
