defmodule SmartKioskWeb.UI.DeliveryZoneLive.FormComponent do
  use SmartKioskWeb, :live_component

  alias SmartKioskCore.Deliveries
  alias SmartKioskCore.Schemas.DeliveryZone

  @impl true
  def update(%{zone: zone} = assigns, socket) do
    changeset = DeliveryZone.changeset(zone, %{})
    boundary_json = encode_boundary(zone.boundary)
    shop_name = assigns[:shop_name] || "Selected shop"

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:boundary_json, boundary_json)
     |> assign(:shop_name, shop_name)
     |> assign(:current_shop, assigns[:current_shop])
     |> assign(:draft_zone_params, %{})
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"delivery_zone" => zone_params}, socket) do
    boundary_json = Map.get(zone_params, "boundary", "")

    changeset =
      socket.assigns.zone
      |> DeliveryZone.changeset(zone_params)
      |> Map.put(:action, :validate)

    if boundary_json != "" and changeset.valid? do
      save_zone(socket, socket.assigns.action, zone_params)
    else
      {:noreply,
       socket
       |> assign(:boundary_json, boundary_json)
       |> assign(:draft_zone_params, zone_params)
       |> assign_form(changeset)}
    end
  end

  def handle_event("save", _params, socket) do
    save_zone(socket, socket.assigns.action, socket.assigns.draft_zone_params)
  end

  defp save_zone(socket, :edit, zone_params) do
    case Deliveries.update_delivery_zone(socket.assigns.zone, zone_params) do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Delivery zone updated successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_zone(socket, :new, zone_params) do
    case Deliveries.create_delivery_zone(zone_params, socket.assigns[:current_shop]) do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Delivery zone created successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp encode_boundary(nil), do: ""

  defp encode_boundary(boundary) when is_binary(boundary), do: boundary

  defp encode_boundary(boundary) when is_map(boundary), do: Jason.encode!(boundary)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h2 class="text-xl font-bold text-white mb-6"><%= @title %></h2>
      <p class="text-sm text-slate-400 mb-4">
        Drawing zone for <span class="text-violet-400 font-semibold"><%= @shop_name %></span>
      </p>

      <.form
        for={@form}
        id="delivery-zone-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-6">
          <div class="space-y-2">
            <label for={@form[:name].id} class="block text-sm font-medium text-slate-400">
              Zone Name
            </label>
            <.input field={@form[:name]} type="text" placeholder="e.g. Westlands & Parklands" />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="space-y-2">
              <label for={@form[:base_fee].id} class="block text-sm font-medium text-slate-400">
                Base Delivery Fee (KES)
              </label>
              <.input field={@form[:base_fee]} type="number" step="0.01" />
            </div>
            <div class="pt-8">
              <.input field={@form[:active]} type="checkbox" label="Active" />
            </div>
          </div>

          <div class="bg-violet-900/10 border border-violet-500/20 rounded-xl p-4">
            <label class="block text-sm font-medium text-slate-400 mb-2">Boundary Definition</label>
            <p class="text-[10px] text-slate-500 mb-3 italic">
              Draw the delivery polygon directly on the map. Click the polygon tool, then click around the area you want to serve.
            </p>

            <div class="space-y-3">
              <div
                id="delivery-zone-map"
                phx-hook="DeliveryZoneMap"
                phx-update="ignore"
                data-boundary-input-id="delivery-zone-boundary"
                data-shop-name={@shop_name}
                data-initial-geojson={@boundary_json}
                class="w-full h-96 rounded-2xl border border-white/10 overflow-hidden bg-slate-900"
              >
              </div>

              <input
                type="hidden"
                id="delivery-zone-boundary"
                name="delivery_zone[boundary]"
                value={@boundary_json}
              />

              <div class="rounded-xl border border-white/10 bg-white/5 p-3 text-xs text-slate-400">
                <p class="font-semibold text-slate-300 mb-1">Tip</p>
                <p>
                  Use the polygon tool to outline the area. Drag points to refine the zone. Clearing the shape removes the delivery zone.
                </p>
              </div>
            </div>
          </div>

          <div class="flex items-center justify-end gap-3 pt-6">
            <button
              type="button"
              phx-click={JS.patch(@return_to)}
              class="px-4 py-2 text-slate-400 hover:text-white transition-all text-sm font-medium"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="save"
              phx-target={@myself}
              phx-disable-with="Saving..."
              class="px-6 py-2 bg-violet-600 hover:bg-violet-500 text-white rounded-xl font-bold transition-all shadow-lg shadow-violet-500/20"
            >
              Save Zone
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
