defmodule SmartKioskWeb.UI.DeliveryZoneLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Deliveries
  alias SmartKioskCore.Schemas.DeliveryZone

  @impl true
  def mount(_params, _session, socket) do
    zones = list_zones(socket)
    {:ok, assign(socket, zones: zones, page_title: "Delivery Zones")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:zones, list_zones(socket))
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    zone = get_zone(socket, id)

    socket
    |> assign(:page_title, "Edit Delivery Zone")
    |> assign(:zone, zone)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Delivery Zone")
    |> assign(:zone, %DeliveryZone{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Delivery Zones")
    |> assign(:zone, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    zone = get_zone(socket, id)
    {:ok, _} = Deliveries.delete_delivery_zone(zone)

    {:noreply, update(socket, :zones, fn zones -> Enum.reject(zones, &(&1.id == id)) end)}
  end

  @impl true
  def handle_event("map_ready", _params, socket), do: {:noreply, socket}

  defp boundary_json(nil), do: ""
  defp boundary_json(boundary) when is_binary(boundary), do: boundary
  defp boundary_json(boundary) when is_map(boundary), do: Jason.encode!(boundary)

  defp list_zones(socket) do
    case socket.assigns[:current_shop] do
      %SmartKioskCore.Schemas.Shop{} = shop -> Deliveries.list_delivery_zones(shop)
      _ -> Deliveries.list_delivery_zones()
    end
  end

  defp get_zone(socket, id) do
    case socket.assigns[:current_shop] do
      %SmartKioskCore.Schemas.Shop{} = shop -> Deliveries.get_delivery_zone!(shop, id)
      _ -> Deliveries.get_delivery_zone!(id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/delivery-zones" current_user={@current_user}>
      <div class="p-6 max-w-7xl mx-auto">
        <header class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-white">Delivery Zones</h1>
            <p class="text-slate-400">Define geographic areas for delivery and their base fees.</p>
          </div>
          <.link
            patch={~p"/delivery-zones/new"}
            class="px-4 py-2 bg-violet-600 hover:bg-violet-500 text-white rounded-xl font-semibold transition-all flex items-center gap-2"
          >
            <.icon name="hero-plus" class="w-5 h-5" /> New Zone
          </.link>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for zone <- @zones do %>
            <div class="bg-white/5 border border-white/10 rounded-2xl p-6 hover:border-violet-500/30 transition-all group">
              <div class="flex items-start justify-between mb-4">
                <div class="w-12 h-12 bg-violet-500/10 rounded-xl flex items-center justify-center">
                  <.icon name="hero-map" class="w-6 h-6 text-violet-400" />
                </div>
                <div class="flex items-center gap-2">
                  <span class={[
                    "px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider",
                    zone.active && "bg-green-500/10 text-green-400",
                    !zone.active && "bg-slate-500/10 text-slate-400"
                  ]}>
                    <%= if zone.active, do: "Active", else: "Inactive" %>
                  </span>
                </div>
              </div>

              <h3 class="text-lg font-bold text-white mb-1"><%= zone.name %></h3>
              <p class="text-2xl font-mono font-bold text-violet-400 mb-6">
                KES <%= zone.base_fee %>
              </p>

              <div :if={@live_action not in [:new, :edit]} class="mb-4">
                <div
                  id={"delivery-zone-preview-#{zone.id}"}
                  phx-hook="DeliveryZoneMap"
                  phx-update="ignore"
                  data-readonly="true"
                  data-initial-geojson={boundary_json(zone.boundary)}
                  class="w-full h-48 rounded-xl border border-white/10 overflow-hidden bg-slate-900"
                >
                </div>
              </div>

              <div class="flex items-center gap-3 pt-4 border-t border-white/5">
                <.link
                  patch={~p"/delivery-zones/#{zone.id}/edit"}
                  class="flex-1 text-center py-2 bg-white/5 hover:bg-white/10 rounded-lg text-sm font-medium transition-all"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={zone.id}
                  data-confirm="Are you sure you want to delete this zone?"
                  class="p-2 text-slate-500 hover:text-red-400 transition-all"
                >
                  <.icon name="hero-trash" class="w-5 h-5" />
                </button>
              </div>
            </div>
          <% end %>

          <%= if @zones == [] do %>
            <div class="col-span-full py-20 text-center bg-white/5 border border-dashed border-white/10 rounded-3xl">
              <.icon name="hero-map" class="w-16 h-16 text-slate-600 mx-auto mb-4" />
              <h3 class="text-xl font-semibold text-slate-400">No delivery zones defined</h3>
              <p class="text-slate-500 mt-2 max-w-sm mx-auto">
                Create your first delivery zone to start accepting orders with automated delivery fees.
              </p>
              <.link
                patch={~p"/delivery-zones/new"}
                class="mt-6 inline-block text-violet-400 font-bold hover:text-violet-300"
              >
                Create a zone now &rarr;
              </.link>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <.modal id="delivery-zone-modal" show on_cancel={JS.patch(~p"/delivery-zones")}>
          <.live_component
            module={SmartKioskWeb.UI.DeliveryZoneLive.FormComponent}
            id={@zone.id || :new}
            title={@page_title}
            action={@live_action}
            zone={@zone}
            current_shop={@current_shop}
            shop_name={@current_shop && @current_shop.name}
            return_to={~p"/delivery-zones"}
          />
        </.modal>
      <% end %>

      <%!-- Include Leaflet and Leaflet.draw via CDN for the zone editor --%>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <link
        rel="stylesheet"
        href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css"
      />
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js">
      </script>
      <script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js">
      </script>
    </Layouts.app>
    """
  end
end
