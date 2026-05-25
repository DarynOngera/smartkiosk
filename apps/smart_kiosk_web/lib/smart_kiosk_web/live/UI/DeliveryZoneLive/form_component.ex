defmodule SmartKioskWeb.UI.DeliveryZoneLive.FormComponent do
  use SmartKioskWeb, :live_component

  alias SmartKioskCore.Deliveries
  alias SmartKioskCore.Schemas.DeliveryZone

  @impl true
  def update(%{zone: zone} = assigns, socket) do
    changeset = DeliveryZone.changeset(zone, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"delivery_zone" => zone_params}, socket) do
    changeset =
      socket.assigns.zone
      |> DeliveryZone.changeset(zone_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"delivery_zone" => zone_params}, socket) do
    save_zone(socket, socket.assigns.action, zone_params)
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
    case Deliveries.create_delivery_zone(zone_params) do
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h2 class="text-xl font-bold text-white mb-6"><%= @title %></h2>

      <.form for={@form} id="delivery-zone-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-6">
          <.input field={@form[:name]} type="text" label="Zone Name" placeholder="e.g. Westlands & Parklands" />

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input field={@form[:base_fee]} type="number" label="Base Delivery Fee (KES)" step="0.01" />
            <div class="pt-8">
              <.input field={@form[:active]} type="checkbox" label="Active" />
            </div>
          </div>

          <div class="bg-violet-900/10 border border-violet-500/20 rounded-xl p-4">
            <label class="block text-sm font-medium text-slate-400 mb-2">Boundary Definition (GeoJSON)</label>
            <p class="text-[10px] text-slate-500 mb-3 italic">
              Phase 3 Tip: Paste a GeoJSON Polygon here. In the next update, we will add a map drawing tool.
            </p>
            <.input
              field={@form[:boundary]}
              type="textarea"
              placeholder='{"type": "Polygon", "coordinates": [[[36.8, -1.2], [36.9, -1.2], ...]]}'
              class="font-mono text-xs h-32"
            />
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
              type="submit"
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
