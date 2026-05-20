defmodule SmartKioskWeb.UI.Inventory.InventoryLive.AdjustStockComponent do
  use SmartKioskWeb, :live_component

  alias SmartKioskCore.Catalogue

  @impl true
  def update(%{product: product, current_user: current_user} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn ->
        to_form(changeset(%{"qty_delta" => "", "reason" => "restock", "notes" => ""}),
          as: :adjust
        )
      end)

    {:ok, socket |> assign(:product, product) |> assign(:current_user, current_user)}
  end

  @impl true
  def handle_event("validate", %{"adjust" => params}, socket) do
    {:noreply,
     assign(socket, :form, to_form(Map.put(changeset(params), :action, :validate), as: :adjust))}
  end

  @impl true
  def handle_event("save", %{"adjust" => params}, socket) do
    product = socket.assigns.product
    current_user = socket.assigns.current_user

    case changeset(params) do
      %Ecto.Changeset{valid?: true} = cs ->
        qty_delta = Ecto.Changeset.get_field(cs, :qty_delta)
        reason = Ecto.Changeset.get_field(cs, :reason)
        notes = Ecto.Changeset.get_field(cs, :notes)

        case Catalogue.adjust_stock_with_reason(
               product,
               qty_delta,
               %{reason: reason, notes: notes},
               current_user
             ) do
          {:ok, _updated_product} ->
            send(self(), {:stock_adjusted, product.id})
            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset, as: :adjust))}
        end

      changeset ->
        {:noreply,
         assign(socket, :form, to_form(Map.put(changeset, :action, :validate), as: :adjust))}
    end
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_adjust_stock)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div
        phx-click="close"
        phx-target={@myself}
        class="absolute inset-0 bg-black/60 backdrop-blur-sm"
      >
      </div>

      <div class="relative bg-[#0B0F1A] border border-white/10 rounded-2xl w-full max-w-xl max-h-[90vh] overflow-y-auto m-4 shadow-2xl">
        <div class="flex items-center justify-between p-6 border-b border-white/10">
          <div class="min-w-0">
            <h2 class="text-xl font-bold text-white">Adjust Stock</h2>
            <p class="text-sm text-slate-400 mt-1 truncate"><%= @product.name %></p>
          </div>
          <button
            type="button"
            phx-click="close"
            phx-target={@myself}
            class="p-2 rounded-lg hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <.form
          for={@form}
          id={"adjust-stock-form-#{@product.id}"}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="p-6 space-y-5"
        >
          <div>
            <span class="label mb-1">Quantity Delta</span>
            <.input field={@form[:qty_delta]} type="number" placeholder="e.g. 10 or -3" />
            <p class="mt-2 text-xs text-slate-500">
              Use positive for restock, negative for write-off.
            </p>
            <.error :for={msg <- Keyword.get_values(@form.source.errors, :qty_delta)}>
              <%= elem(msg, 0) %>
            </.error>
          </div>

          <div>
            <span class="label mb-1">Reason</span>
            <.input
              field={@form[:reason]}
              type="select"
              options={[
                {"Restock", "restock"},
                {"Write-off", "write_off"},
                {"Damaged", "damaged"},
                {"Expiry", "expiry"},
                {"Recount", "recount"},
                {"Other", "other"}
              ]}
            />
            <.error :for={msg <- Keyword.get_values(@form.source.errors, :reason)}>
              <%= elem(msg, 0) %>
            </.error>
          </div>

          <div>
            <span class="label mb-1">Notes (optional)</span>
            <.input field={@form[:notes]} type="textarea" rows="3" placeholder="Extra details…" />
            <.error :for={msg <- Keyword.get_values(@form.source.errors, :notes)}>
              <%= elem(msg, 0) %>
            </.error>
          </div>

          <div class="flex items-center justify-end gap-3 pt-4 border-t border-white/10">
            <button
              type="button"
              phx-click="close"
              phx-target={@myself}
              class="px-6 py-3 bg-white/10 hover:bg-white/20 rounded-xl text-sm font-semibold transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-6 py-3 bg-violet-600 hover:bg-violet-500 rounded-xl text-sm font-semibold transition"
            >
              Apply
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp changeset(params) do
    types = %{qty_delta: :integer, reason: :string, notes: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:qty_delta, :reason])
    |> Ecto.Changeset.validate_number(:qty_delta, not_equal_to: 0)
  end
end
