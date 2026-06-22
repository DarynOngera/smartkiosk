defmodule SmartKioskWeb.UI.ReportsLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Reports

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> assign_reports()}
  end

  @impl true
  def handle_event("generate_report", %{"period" => period}, socket) do
    generate_shop_report(socket, period, "Report generated")
  end

  def handle_event("close_shop", _params, socket) do
    generate_shop_report(
      socket,
      "daily",
      "Daily report generated. Shop closing summary is ready."
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_path="/reports"
      current_user={@current_user}
      current_shop={@current_shop}
      cart_count={@cart_count}
    >
      <div class="min-h-screen bg-[#0B0F1A] px-4 py-8 sm:px-6 lg:px-10">
        <div class="mx-auto max-w-7xl">
          <header class="mb-8 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <.link
                navigate={~p"/dashboard"}
                class="mb-4 inline-flex items-center gap-2 text-sm font-semibold text-slate-400 transition hover:text-white"
              >
                <.icon name="hero-arrow-left" class="h-4 w-4" /> Dashboard
              </.link>
              <h1 class="text-3xl font-bold tracking-tight text-white">Sales Reports</h1>
              <p class="mt-2 max-w-2xl text-sm text-slate-500">
                Review generated daily, weekly, and monthly reports for POS and online sales.
              </p>
            </div>

            <div class="flex flex-wrap gap-3">
              <button
                id="close-shop-report-button"
                type="button"
                phx-click="close_shop"
                disabled={@daily_report_exists?}
                class="inline-flex items-center justify-center gap-2 rounded-xl bg-rose-500 px-4 py-2.5 text-sm font-semibold text-white shadow-lg shadow-rose-500/20 transition hover:bg-rose-400 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <.icon name="hero-lock-closed" class="h-4 w-4" /> Close shop
              </button>
              <button
                id="generate-weekly-report-button"
                type="button"
                phx-click="generate_report"
                phx-value-period="weekly"
                class="inline-flex items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                <.icon name="hero-calendar-days" class="h-4 w-4" /> Weekly
              </button>
              <button
                id="generate-monthly-report-button"
                type="button"
                phx-click="generate_report"
                phx-value-period="monthly"
                class="inline-flex items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                <.icon name="hero-calendar" class="h-4 w-4" /> Monthly
              </button>
            </div>
          </header>

          <section class="rounded-3xl border border-white/10 bg-white/5 p-5 backdrop-blur-xl sm:p-6">
            <div class="mb-5 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-xl font-bold text-white">Generated Reports</h2>
                <p class="mt-1 text-sm text-slate-500">
                  Each report includes revenue, order counts, channel totals, and sold items.
                </p>
              </div>
              <span class="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold text-slate-300">
                <%= length(@reports) %> total
              </span>
            </div>

            <div id="reports-list" class="grid gap-3">
              <%= if @reports == [] do %>
                <div class="rounded-2xl border border-dashed border-white/10 p-8 text-center text-sm text-slate-500">
                  No generated reports yet.
                </div>
              <% else %>
                <%= for report <- @reports do %>
                  <.report_card report={report} />
                <% end %>
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp assign_reports(socket) do
    shop = socket.assigns.current_shop

    socket
    |> assign(:reports, Reports.list_reports(shop, limit: 50))
    |> assign(:daily_report_exists?, Reports.report_exists?(shop, "daily"))
  end

  defp generate_shop_report(socket, period, message) do
    shop = socket.assigns[:current_shop]
    user = socket.assigns[:current_user]

    cond do
      is_nil(shop) ->
        {:noreply, put_flash(socket, :error, "No shop selected")}

      is_nil(user) or user.role != :owner ->
        {:noreply, put_flash(socket, :error, "Only shop owners can generate reports")}

      true ->
        case Reports.generate_report(shop, period) do
          {:ok, _report} ->
            {:noreply,
             socket
             |> assign_reports()
             |> put_flash(:info, message)}

          {:error, :invalid_period} ->
            {:noreply,
             put_flash(socket, :error, "Choose daily, weekly, or monthly report period")}

          {:error, :report_already_exists} ->
            {:noreply,
             socket
             |> assign_reports()
             |> put_flash(:error, "Daily report has already been generated today")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not generate report")}
        end
    end
  end

  defp report_card(assigns) do
    ~H"""
    <article
      id={"report-#{@report.id}"}
      class="grid gap-4 rounded-2xl border border-white/10 bg-slate-950/40 p-4 md:grid-cols-[1fr_auto] md:items-center"
    >
      <div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-300">
            <%= @report.period %>
          </span>
          <span class="text-xs text-slate-500">
            <%= Calendar.strftime(@report.starts_at, "%d %b %Y") %> - <%= Calendar.strftime(
              @report.ends_at,
              "%d %b %Y"
            ) %>
          </span>
        </div>

        <div class="mt-3 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          <div>
            <p class="text-slate-500">Revenue</p>
            <p class="font-semibold text-white">KES <%= format_money(@report.total_revenue) %></p>
          </div>
          <div>
            <p class="text-slate-500">Orders</p>
            <p class="font-semibold text-white"><%= @report.total_orders %></p>
          </div>
          <div>
            <p class="text-slate-500">POS</p>
            <p class="font-semibold text-white">
              <%= @report.pos_orders || 0 %> / KES <%= report_channel_revenue(
                @report,
                "pos_revenue"
              ) %>
            </p>
          </div>
          <div>
            <p class="text-slate-500">Online</p>
            <p class="font-semibold text-white">
              <%= @report.online_orders || 0 %> / KES <%= report_channel_revenue(
                @report,
                "online_revenue"
              ) %>
            </p>
          </div>
        </div>

        <div class="mt-4 rounded-2xl border border-white/10 bg-white/[0.03] p-3">
          <div class="mb-2 flex items-center justify-between gap-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Items sold</p>
            <p class="text-xs text-slate-500"><%= @report.total_items || 0 %> units</p>
          </div>
          <%= if report_items_sold(@report) == [] do %>
            <p class="text-sm text-slate-500">No items sold in this period.</p>
          <% else %>
            <div class="divide-y divide-white/10">
              <div
                :for={item <- report_items_sold(@report)}
                class="grid gap-2 py-2 text-sm sm:grid-cols-[1fr_auto] sm:items-center"
              >
                <div class="min-w-0">
                  <p class="truncate font-medium text-white"><%= item["product_name"] %></p>
                  <p class="text-xs text-slate-500">
                    POS <%= item["pos_quantity"] || 0 %> • Online <%= item["online_quantity"] ||
                      0 %>
                  </p>
                </div>
                <div class="text-left sm:text-right">
                  <p class="font-semibold text-slate-200"><%= item["quantity"] || 0 %> units</p>
                  <p class="text-xs text-slate-500">KES <%= report_item_revenue(item) %></p>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 justify-self-start md:justify-self-end">
        <span class="rounded-full bg-emerald-500/15 px-3 py-1 text-xs font-semibold text-emerald-300">
          <%= @report.status %>
        </span>
        <.link
          navigate={~p"/reports/#{@report.id}"}
          class="inline-flex items-center gap-1 text-xs font-semibold text-violet-400 transition-colors hover:text-violet-300"
        >
          <.icon name="hero-eye" class="h-3.5 w-3.5" /> View
        </.link>
        <%= if @report.status == "ready" && @report.file_path do %>
          <a
            href={@report.file_path}
            target="_blank"
            class="inline-flex items-center gap-1 text-xs font-semibold text-violet-400 transition-colors hover:text-violet-300"
          >
            <.icon name="hero-arrow-down-tray" class="h-3.5 w-3.5" /> PDF
          </a>
        <% end %>
      </div>
    </article>
    """
  end

  defp format_money(nil), do: "0.00"

  defp format_money(amount) do
    amount
    |> Decimal.to_float()
    |> :erlang.float_to_binary(decimals: 2)
  end

  defp report_channel_revenue(%{metadata: metadata}, key) when is_map(metadata) do
    metadata
    |> Map.get(key, "0")
    |> Decimal.new()
    |> format_money()
  end

  defp report_channel_revenue(_report, _key), do: "0.00"

  defp report_items_sold(%{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, "items_sold") do
      items when is_list(items) -> items
      _items -> []
    end
  end

  defp report_items_sold(_report), do: []

  defp report_item_revenue(%{"revenue" => revenue}) when is_binary(revenue) do
    revenue
    |> Decimal.new()
    |> format_money()
  end

  defp report_item_revenue(_item), do: "0.00"
end
