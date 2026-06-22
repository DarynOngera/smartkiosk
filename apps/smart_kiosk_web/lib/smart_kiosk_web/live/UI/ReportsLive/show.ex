defmodule SmartKioskWeb.UI.ReportsLive.Show do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Reports

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    report = Reports.get_report!(id)

    if report.shop_id == socket.assigns.current_shop.id do
      {:ok,
       socket
       |> assign(:page_title, "Report")
       |> assign(:report, report)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Report not found")
       |> push_navigate(to: ~p"/reports")}
    end
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
        <div class="mx-auto max-w-4xl">
          <.link
            navigate={~p"/reports"}
            class="mb-6 inline-flex items-center gap-2 text-sm font-semibold text-slate-400 transition hover:text-white"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Reports
          </.link>

          <article class="rounded-3xl border border-white/10 bg-white/5 p-6 text-slate-300 backdrop-blur-xl">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <span class="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-300">
                  <%= @report.period %>
                </span>
                <h1 class="mt-4 text-3xl font-bold text-white">Sales Report</h1>
                <p class="mt-2 text-sm text-slate-500">
                  <%= Calendar.strftime(@report.starts_at, "%d %b %Y") %> - <%= Calendar.strftime(
                    @report.ends_at,
                    "%d %b %Y"
                  ) %>
                </p>
              </div>

              <%= if @report.status == "ready" && @report.file_path do %>
                <a
                  id="report-pdf-link"
                  href={@report.file_path}
                  target="_blank"
                  class="inline-flex items-center justify-center gap-2 rounded-xl bg-violet-500 px-4 py-2.5 text-sm font-semibold text-white shadow-lg shadow-violet-500/20 transition hover:bg-violet-400"
                >
                  <.icon name="hero-arrow-down-tray" class="h-4 w-4" /> Download PDF
                </a>
              <% end %>
            </div>

            <div class="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <.metric label="Revenue" value={"KES #{format_money(@report.total_revenue)}"} />
              <.metric label="Orders" value={@report.total_orders} />
              <.metric label="POS" value={@report.pos_orders || 0} />
              <.metric label="Online" value={@report.online_orders || 0} />
            </div>

            <section class="mt-8 rounded-2xl border border-white/10 bg-slate-950/40 p-4">
              <div class="mb-3 flex items-center justify-between gap-3">
                <h2 class="text-base font-semibold text-white">Items sold</h2>
                <span class="text-xs text-slate-500"><%= @report.total_items || 0 %> units</span>
              </div>
              <%= if report_items_sold(@report) == [] do %>
                <p class="text-sm text-slate-500">No items sold in this period.</p>
              <% else %>
                <div class="divide-y divide-white/10">
                  <div
                    :for={item <- report_items_sold(@report)}
                    id={"report-item-#{item["product_id"]}"}
                    class="grid gap-2 py-3 text-sm sm:grid-cols-[1fr_auto] sm:items-center"
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
            </section>
          </article>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp metric(assigns) do
    ~H"""
    <div class="rounded-2xl border border-white/10 bg-slate-950/40 p-4">
      <p class="text-xs font-semibold uppercase tracking-wide text-slate-500"><%= @label %></p>
      <p class="mt-2 text-xl font-bold text-white"><%= @value %></p>
    </div>
    """
  end

  defp format_money(nil), do: "0.00"

  defp format_money(amount) do
    amount
    |> Decimal.to_float()
    |> :erlang.float_to_binary(decimals: 2)
  end

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
