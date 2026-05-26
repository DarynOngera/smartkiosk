defmodule SmartKioskWeb.UI.DashboardLive do
  @moduledoc """
  Unified dashboard for both Customers and Shop Owners.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Orders
  alias SmartKioskCore.Shops
  import SmartKioskWeb.Components.ProductCard

  def mount(_params, _session, socket) do
    _user = socket.assigns[:current_user]
    shop = socket.assigns[:current_shop]

    products = if shop, do: Catalogue.list_products(shop, limit: 10), else: []
    pending = if shop, do: Orders.get_pending_orders(shop), else: []

    socket =
      if shop do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(SmartKiosk.PubSub, "shop:#{shop.id}:inventory")
        end

        # Merchant Stats
        socket
        |> assign(:page_title, "Merchant Dashboard")
        |> assign(:sales_today, "KES 0.00")
        |> assign(:inventory_count, Catalogue.count_products(shop))
        |> assign(:pending_orders, pending |> Enum.count())
        |> assign(:products, products)
        |> assign(:low_stock_products, Catalogue.list_low_stock_products(shop))
      else
        # Customer Stats
        socket
        |> assign(:page_title, "Customer Dashboard")
        |> assign(:total_spent, "KES 0.00")
        |> assign(:orders_count, 0)
        |> assign(:loyalty_points, 0)
      end

    {:ok, socket}
  end

  def handle_info({:low_stock, _product}, socket) do
    shop = socket.assigns.current_shop

    {:noreply, assign(socket, :low_stock_products, Catalogue.list_low_stock_products(shop))}
  end

  @doc "Handle client-drawn delivery zone GeoJSON payloads"
  def handle_event("zone_drawn", payload, socket) do
    # store pending geojson so admin can save later
    {:noreply, assign(socket, :pending_zone_geojson, payload)}
  end

  def handle_event("map_ready", %{"shop_id" => _shop_id}, socket) do
    # no-op for now; could be used to push existing zone to client
    {:noreply, socket}
  end

  def handle_event("save_zone", _params, socket) do
    shop = socket.assigns[:current_shop]
    pending = socket.assigns[:pending_zone_geojson]

    cond do
      shop == nil ->
        {:noreply, put_flash(socket, :error, "No shop selected")}

      pending in [nil, %{}] or pending == %{} ->
        # clear existing zone
        case Shops.update_shop(shop, %{delivery_zone: nil}) do
          {:ok, shop} ->
            {:noreply,
             socket
             |> assign(:current_shop, shop)
             |> assign(:pending_zone_geojson, %{})
             |> put_flash(:info, "Delivery zone cleared")}

          {:error, cs} ->
            {:noreply, put_flash(socket, :error, "Failed to clear zone: #{inspect(cs.errors)}")}
        end

      true ->
        # attempt to decode GeoJSON to a Geo.* struct
        geom =
          extract_geometry_from_geojson(pending)

        case geom do
          {:ok, g} ->
            # ensure SRID 4326
            g = if Map.get(g, :srid), do: g, else: Map.put(g, :srid, 4326)

            case Shops.update_shop(shop, %{delivery_zone: g}) do
              {:ok, shop} ->
                {:noreply,
                 socket
                 |> assign(:current_shop, shop)
                 |> assign(:pending_zone_geojson, %{})
                 |> put_flash(:info, "Delivery zone saved")}

              {:error, cs} ->
                {:noreply,
                 put_flash(socket, :error, "Failed to save zone: #{inspect(cs.errors)}")}
            end

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Invalid GeoJSON: #{reason}")}
        end
    end
  end

  def handle_event("clear_zone", _params, socket) do
    shop = socket.assigns[:current_shop]

    if shop do
      case Shops.update_shop(shop, %{delivery_zone: nil}) do
        {:ok, shop} ->
          {:noreply, assign(socket, :current_shop, shop) |> assign(:pending_zone_geojson, %{})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to clear zone")}
      end
    else
      {:noreply, put_flash(socket, :error, "No shop selected")}
    end
  end

  defp extract_geometry_from_geojson(nil), do: {:error, "no payload"}

  defp extract_geometry_from_geojson(%{} = obj) do
    # obj may be a Feature, FeatureCollection, or raw Geometry
    try do
      geom =
        cond do
          Map.get(obj, "type") == "Feature" and Map.has_key?(obj, "geometry") ->
            Geo.JSON.decode!(obj["geometry"])

          Map.get(obj, "type") == "FeatureCollection" and is_list(obj["features"]) ->
            first = List.first(obj["features"]) || %{}
            Geo.JSON.decode!(first["geometry"] || first)

          Map.get(obj, "type") in ["Polygon", "MultiPolygon", "Point"] ->
            Geo.JSON.decode!(obj)

          true ->
            Geo.JSON.decode!(obj)
        end

      {:ok, geom}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def merchant_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
      <%!-- Stats Cards --%>
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-emerald-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-banknotes" class="w-6 h-6 text-emerald-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Sales Today</p>
            <p class="text-2xl font-bold text-white"><%= @sales_today %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-violet-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-cube" class="w-6 h-6 text-violet-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Inventory</p>
            <p class="text-2xl font-bold text-white"><%= @inventory_count %> Items</p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-amber-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-clock" class="w-6 h-6 text-amber-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Pending Orders</p>
            <p class="text-2xl font-bold text-white"><%= @pending_orders %></p>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
      <%!-- Inventory List --%>
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <h2 class="text-xl font-bold text-white mb-6">Recent Inventory</h2>
        <div class="space-y-4">
          <%= for product <- @products do %>
            <.product_card product={product} />
          <% end %>
        </div>
      </div>

      <%!-- Quick Actions --%>
      <div class="space-y-4">
        <h2 class="text-xl font-bold text-white mb-4">Quick Management</h2>
        <div class="grid grid-cols-2 gap-4">
          <.link
            navigate="/inventory"
            class="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors group"
          >
            <.icon
              name="hero-plus-circle"
              class="w-8 h-8 text-violet-400 mb-3 group-hover:scale-110 transition-transform"
            />
            <p class="font-bold text-white">Add/Remove Stock</p>
            <p class="text-slate-500 text-xs mt-1">Manage your inventory levels</p>
          </.link>

          <.link
            navigate="/orders"
            class="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors group"
          >
            <.icon
              name="hero-truck"
              class="w-8 h-8 text-indigo-400 mb-3 group-hover:scale-110 transition-transform"
            />
            <p class="font-bold text-white">Orders & Deliveries</p>
            <p class="text-slate-500 text-xs mt-1">Track customer shipments</p>
          </.link>

          <.link
            navigate="/delivery-zones"
            class="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors group"
          >
            <.icon
              name="hero-map"
              class="w-8 h-8 text-emerald-400 mb-3 group-hover:scale-110 transition-transform"
            />
            <p class="font-bold text-white">Delivery Zones</p>
            <p class="text-slate-500 text-xs mt-1">Manage geographic boundaries</p>
          </.link>
        </div>
      </div>
    </div>

    <div class="mt-8 bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-bold text-white">Low Stock Alerts</h2>
        <span class="text-sm text-slate-400"><%= length(@low_stock_products) %> items</span>
      </div>

      <%= if @low_stock_products == [] do %>
        <div class="text-slate-500 text-sm">All good — no products are below their threshold.</div>
      <% else %>
        <div class="divide-y divide-white/10">
          <div
            :for={product <- @low_stock_products}
            class="py-3 flex items-center justify-between gap-4"
          >
            <div class="min-w-0">
              <div class="font-medium text-white truncate"><%= product.name %></div>
              <div class="text-xs text-slate-500 truncate"><%= product.sku || "No SKU" %></div>
            </div>
            <div class="shrink-0 text-right">
              <div class="text-sm font-semibold text-amber-300">
                <%= product.stock_qty %> / <%= product.low_stock_threshold %>
              </div>
              <div class="text-xs text-slate-500">in stock</div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def customer_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
      <%!-- Stats Cards --%>
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-indigo-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-shopping-bag" class="w-6 h-6 text-indigo-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Orders Count</p>
            <p class="text-2xl font-bold text-white"><%= @orders_count %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-emerald-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-currency-dollar" class="w-6 h-6 text-emerald-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Total Spent</p>
            <p class="text-2xl font-bold text-white"><%= @total_spent %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-rose-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-star" class="w-6 h-6 text-rose-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Loyalty Points</p>
            <p class="text-2xl font-bold text-white"><%= @loyalty_points %></p>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white/5 border border-white/10 rounded-3xl overflow-hidden">
      <div class="p-6 border-b border-white/10 flex items-center justify-between">
        <h2 class="text-xl font-bold text-white">Recent Purchases</h2>
        <button class="text-sm text-violet-400 font-semibold hover:text-violet-300">View All</button>
      </div>
      <div class="p-20 flex flex-col items-center justify-center text-center">
        <div class="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mb-4">
          <.icon name="hero-shopping-cart" class="w-8 h-8 text-slate-700" />
        </div>
        <p class="text-slate-500 font-medium">No purchases yet.</p>
        <p class="text-slate-600 text-sm mt-1">Items you buy will appear here.</p>
      </div>
    </div>
    """
  end
end
