defmodule SmartKioskWeb.UI.DashboardLive do
  @moduledoc """
  Unified dashboard for both Customers and Shop Owners.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Orders
  alias SmartKioskCore.Shops
  alias SmartKioskCore.Deliveries
  alias SmartKioskCore.Repo
  import SmartKioskWeb.Components.ProductCard

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    shop = socket.assigns[:current_shop]

    socket =
      cond do
        user && user.role == :rider ->
          user = Repo.preload(user, :rider_profile)
          rider_profile = user.rider_profile

          if connected?(socket) && shop do
            Phoenix.PubSub.subscribe(SmartKiosk.PubSub, "shop:#{shop.id}:orders")
            Phoenix.PubSub.subscribe(SmartKiosk.PubSub, "shop:#{shop.id}:deliveries")
          end

          assigned_deliveries =
            if verified_rider?(rider_profile),
              do: Deliveries.list_deliveries_for_rider(rider_profile.id),
              else: []

          active_delivery_count =
            if verified_rider?(rider_profile),
              do: Deliveries.count_active_deliveries_for_rider(rider_profile.id),
              else: 0

          available_deliveries =
            if shop && verified_rider?(rider_profile),
              do: Deliveries.list_available_deliveries(shop),
              else: []

          socket
          |> assign(:page_title, "Rider Dashboard")
          |> assign(:rider_profile, rider_profile)
          |> assign(:assigned_deliveries, assigned_deliveries)
          |> assign(:active_delivery_count, active_delivery_count)
          |> assign(:available_deliveries, available_deliveries)

        shop ->
          if connected?(socket) do
            Phoenix.PubSub.subscribe(SmartKiosk.PubSub, "shop:#{shop.id}:inventory")
          end

          products = Catalogue.list_products(shop, limit: 10)
          pending = Orders.get_pending_orders(shop)

          socket
          |> assign(:page_title, "Merchant Dashboard")
          |> assign(:sales_today, "KES 0.00")
          |> assign(:inventory_count, Catalogue.count_products(shop))
          |> assign(:pending_orders, pending |> Enum.count())
          |> assign(:products, products)
          |> assign(:low_stock_products, Catalogue.list_low_stock_products(shop))

        true ->
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

  def handle_info({:new_order, _order}, socket) do
    if socket.assigns.current_user.role == :rider and
         verified_rider?(socket.assigns[:rider_profile]) do
      {:noreply, refresh_rider_deliveries(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:order_updated, _order}, socket) do
    if socket.assigns.current_user.role == :rider and
         verified_rider?(socket.assigns[:rider_profile]) do
      {:noreply, refresh_rider_deliveries(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  def handle_event("accept_delivery", %{"id" => id}, socket) do
    rider_profile = socket.assigns.rider_profile

    if !verified_rider?(rider_profile) do
      {:noreply, put_flash(socket, :error, "Your rider application is not approved yet")}
    else
      case Deliveries.accept_delivery(id, rider_profile.id) do
        {:ok, _delivery} ->
          {:noreply,
           socket
           |> refresh_rider_deliveries()
           |> put_flash(:info, "Delivery accepted")}

        {:error, :capacity_reached} ->
          {:noreply,
           put_flash(socket, :error, "You can only carry 5 active deliveries at a time")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not accept delivery")}
      end
    end
  end

  def handle_event("update_delivery_status", %{"id" => id, "status" => status}, socket) do
    with {:ok, new_status} <- delivery_status(status),
         {:ok, delivery} <- Deliveries.update_delivery_status(id, new_status) do
      delivery = Repo.preload(delivery, :order)
      sync_order_from_delivery(socket.assigns.current_shop, delivery)

      {:noreply,
       socket
       |> refresh_rider_deliveries()
       |> put_flash(:info, "Delivery status updated")}
    else
      _error ->
        rider_profile = socket.assigns.rider_profile

        {:noreply,
         socket
         |> assign(:assigned_deliveries, Deliveries.list_deliveries_for_rider(rider_profile.id))
         |> put_flash(:error, "Failed to update status")}
    end
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

  def rider_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-emerald-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-truck" class="w-6 h-6 text-emerald-300" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Available Dispatches</p>
            <p class="text-2xl font-bold text-white"><%= length(@available_deliveries) %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-violet-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-map-pin" class="w-6 h-6 text-violet-300" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Active Deliveries</p>
            <p class="text-2xl font-bold text-white">
              <%= @active_delivery_count %><span class="text-base text-slate-400">/5</span>
            </p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-amber-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-identification" class="w-6 h-6 text-amber-300" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Rider Status</p>
            <p class="text-2xl font-bold text-white">
              <%= if @rider_profile,
                do:
                  @rider_profile.status
                  |> to_string()
                  |> String.replace("_", " ")
                  |> String.capitalize(),
                else: "Missing" %>
            </p>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-8">
      <section class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center justify-between gap-4 mb-5">
          <h2 class="text-xl font-bold text-white">Available Dispatches</h2>
          <span class="text-sm text-slate-400"><%= length(@available_deliveries) %> ready</span>
        </div>

        <%= if @available_deliveries == [] do %>
          <div class="rounded-2xl border border-dashed border-white/10 p-8 text-center text-slate-500">
            No dispatched delivery orders are waiting right now.
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for delivery <- @available_deliveries do %>
              <.delivery_card
                delivery={delivery}
                action={:accept}
                active_delivery_count={@active_delivery_count}
              />
            <% end %>
          </div>
        <% end %>
      </section>

      <section class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center justify-between gap-4 mb-5">
          <h2 class="text-xl font-bold text-white">My Active Deliveries</h2>
          <span class="text-sm text-slate-400"><%= length(@assigned_deliveries) %> assigned</span>
        </div>

        <%= if @assigned_deliveries == [] do %>
          <div class="rounded-2xl border border-dashed border-white/10 p-8 text-center text-slate-500">
            Accepted deliveries will appear here with their pickup and dropoff map.
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for delivery <- @assigned_deliveries do %>
              <.delivery_card
                delivery={delivery}
                action={:manage}
                active_delivery_count={@active_delivery_count}
              />
            <% end %>
          </div>
        <% end %>
      </section>
    </div>
    """
  end

  def delivery_card(assigns) do
    ~H"""
    <article class="rounded-2xl border border-white/10 bg-slate-950/50 overflow-hidden">
      <div class="p-5">
        <div class="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
          <div>
            <div class="flex items-center gap-2">
              <span class="text-xs font-semibold uppercase tracking-wide text-violet-300">
                Order <%= short_id(@delivery.order_id) %>
              </span>
              <span class="rounded-full bg-white/10 px-2 py-1 text-xs text-slate-300">
                <%= @delivery.status |> to_string() |> String.replace("_", " ") |> String.capitalize() %>
              </span>
            </div>
            <h3 class="mt-2 text-lg font-semibold text-white">
              <%= customer_name(@delivery) %>
            </h3>
            <p class="mt-1 text-sm text-slate-400">
              <%= @delivery.order.delivery_address || "Delivery point not set" %>
            </p>
          </div>

          <%= if @action == :accept do %>
            <button
              id={"accept-delivery-#{@delivery.id}"}
              phx-click="accept_delivery"
              phx-value-id={@delivery.id}
              disabled={@active_delivery_count >= 5}
              class="inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-emerald-400"
            >
              <.icon name="hero-check-circle" class="w-4 h-4" /> Accept
            </button>
          <% else %>
            <div class="flex flex-wrap gap-2">
              <button
                id={"complete-delivery-#{@delivery.id}"}
                phx-click="update_delivery_status"
                phx-value-id={@delivery.id}
                phx-value-status="delivered"
                class="inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-emerald-400"
              >
                <.icon name="hero-check" class="w-4 h-4" /> Delivered
              </button>
            </div>
          <% end %>
        </div>

        <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
          <div class="rounded-xl bg-white/5 p-3">
            <p class="text-slate-500">Pickup</p>
            <p class="font-medium text-slate-200"><%= pickup_label(@delivery) %></p>
          </div>
          <div class="rounded-xl bg-white/5 p-3">
            <p class="text-slate-500">Items</p>
            <p class="font-medium text-slate-200"><%= delivery_items(@delivery) %></p>
          </div>
        </div>
      </div>

      <%= if map_ready?(@delivery) do %>
        <iframe
          id={"delivery-map-#{@delivery.id}"}
          title={"Delivery map for order #{short_id(@delivery.order_id)}"}
          src={map_embed_url(@delivery)}
          class="h-64 w-full border-0"
          loading="lazy"
        >
        </iframe>
        <div class="flex flex-wrap items-center justify-between gap-3 border-t border-white/10 px-5 py-3 text-xs text-slate-400">
          <span>Dropoff: <%= @delivery.dropoff_lat %>, <%= @delivery.dropoff_lng %></span>
          <a
            href={directions_url(@delivery)}
            target="_blank"
            class="inline-flex items-center gap-1 font-semibold text-violet-300 hover:text-violet-200"
          >
            Open directions <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
          </a>
        </div>
      <% else %>
        <div class="border-t border-white/10 px-5 py-4 text-sm text-amber-300">
          Delivery coordinates are missing for this order.
        </div>
      <% end %>
    </article>
    """
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
          <.link
            navigate="/manage-staff"
            class="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors group"
          >
            <.icon
              name="hero-users"
              class="w-8 h-8 text-emerald-400 mb-3 group-hover:scale-110 transition-transform"
            />
            <p class="font-bold text-white">Manage Staff</p>
            <p class="text-slate-500 text-xs mt-1">Manage Your Staff</p>
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

  defp refresh_rider_deliveries(socket) do
    rider_profile = socket.assigns[:rider_profile]
    shop = socket.assigns[:current_shop]

    socket
    |> assign(
      :assigned_deliveries,
      if(verified_rider?(rider_profile),
        do: Deliveries.list_deliveries_for_rider(rider_profile.id),
        else: []
      )
    )
    |> assign(
      :active_delivery_count,
      if(verified_rider?(rider_profile),
        do: Deliveries.count_active_deliveries_for_rider(rider_profile.id),
        else: 0
      )
    )
    |> assign(
      :available_deliveries,
      if(shop && verified_rider?(rider_profile),
        do: Deliveries.list_available_deliveries(shop),
        else: []
      )
    )
  end

  defp verified_rider?(%{verification_status: :verified}), do: true
  defp verified_rider?(_rider_profile), do: false

  defp delivery_status("picked_up"), do: {:ok, :picked_up}
  defp delivery_status("in_transit"), do: {:ok, :in_transit}
  defp delivery_status("delivered"), do: {:ok, :delivered}
  defp delivery_status("failed"), do: {:ok, :failed}
  defp delivery_status(_status), do: {:error, :invalid_status}

  defp sync_order_from_delivery(shop, %{status: :delivered, order: %{id: order_id}}) do
    sync_order_status(shop, order_id, :delivered)
  end

  defp sync_order_from_delivery(_shop, _delivery), do: :ok

  defp sync_order_status(nil, _order_id, _status), do: :ok

  defp sync_order_status(shop, order_id, status) do
    _ = Orders.update_order_status(shop, order_id, status)

    Phoenix.PubSub.broadcast(
      SmartKiosk.PubSub,
      "shop:#{shop.id}:orders",
      {:order_updated, Orders.get_order!(shop, order_id)}
    )
  end

  defp customer_name(%{order: %{customer: %{name: name}}}) when is_binary(name) and name != "",
    do: name

  defp customer_name(_delivery), do: "Customer"

  defp pickup_label(%{order: %{shop: %{name: name, address: address}}}) do
    [name, address]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(" - ")
    |> case do
      "" -> "Shop pickup point"
      label -> label
    end
  end

  defp pickup_label(_delivery), do: "Shop pickup point"

  defp delivery_items(%{order: %{items: items}}) when is_list(items) do
    items
    |> Enum.map(fn item -> "#{item.quantity}x #{item.product_name}" end)
    |> Enum.join(", ")
    |> case do
      "" -> "No items"
      label -> label
    end
  end

  defp delivery_items(_delivery), do: "No items"

  defp short_id(nil), do: "unknown"
  defp short_id(id), do: id |> to_string() |> String.slice(0, 8)

  defp map_ready?(%{dropoff_lat: lat, dropoff_lng: lng}) when is_number(lat) and is_number(lng),
    do: true

  defp map_ready?(_delivery), do: false

  defp map_embed_url(delivery) do
    lat = delivery.dropoff_lat
    lng = delivery.dropoff_lng
    delta = 0.01

    "https://www.openstreetmap.org/export/embed.html?bbox=#{lng - delta}%2C#{lat - delta}%2C#{lng + delta}%2C#{lat + delta}&layer=mapnik&marker=#{lat}%2C#{lng}"
  end

  defp directions_url(%{pickup_lat: pickup_lat, pickup_lng: pickup_lng} = delivery)
       when is_number(pickup_lat) and is_number(pickup_lng) do
    "https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=#{pickup_lat}%2C#{pickup_lng}%3B#{delivery.dropoff_lat}%2C#{delivery.dropoff_lng}"
  end

  defp directions_url(delivery) do
    "https://www.openstreetmap.org/?mlat=#{delivery.dropoff_lat}&mlon=#{delivery.dropoff_lng}#map=16/#{delivery.dropoff_lat}/#{delivery.dropoff_lng}"
  end
end
