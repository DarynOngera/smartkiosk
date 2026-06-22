defmodule SmartKioskCore.Reports do
  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Order, Report, Shop}

  @periods ~w(daily weekly monthly)

  @doc """
  Generates a report for a given shop and period.
  """
  def generate_sales_summary(%Shop{} = shop, from_date, to_date) do
    query =
      from(o in Order,
        where: o.shop_id == ^shop.id,
        where: o.status != :cancelled,
        where: o.inserted_at >= ^from_date and o.inserted_at <= ^to_date,
        preload: [:transactions, :items]
      )

    orders = Repo.all(query)

    total_orders = length(orders)
    total_revenue = Enum.reduce(orders, Decimal.new("0"), &Decimal.add(&2, &1.total || 0))
    online_orders = Enum.count(orders, &(&1.channel == :online))
    pos_orders = total_orders - online_orders
    online_revenue = revenue_for_channel(orders, :online)
    pos_revenue = revenue_for_channel(orders, :pos)
    total_items = total_items_count(orders)
    items_sold = items_sold_summary(orders)

    %{
      total_orders: total_orders,
      total_revenue: total_revenue,
      total_items: total_items,
      online_orders: online_orders,
      pos_orders: pos_orders,
      metadata: %{
        "online_revenue" => Decimal.to_string(online_revenue),
        "pos_revenue" => Decimal.to_string(pos_revenue),
        "items_sold" => items_sold,
        "generated_at" =>
          DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
      }
    }
  end

  @doc """
  Generate and persist a sales report for a shop.
  """
  def generate_report(%Shop{} = shop, period, now \\ DateTime.utc_now()) do
    with {:ok, period} <- normalize_period(period) do
      {starts_at, ends_at} = period_range(period, now)

      if duplicate_daily_report?(shop, period, starts_at, ends_at) do
        {:error, :report_already_exists}
      else
        summary = generate_sales_summary(shop, starts_at, ends_at)

        case create_report(shop, period, starts_at, ends_at, summary) do
          {:ok, report} ->
            generate_pdf(report)

          {:error, changeset} ->
            if daily_report_constraint_error?(changeset) do
              {:error, :report_already_exists}
            else
              {:error, changeset}
            end
        end
      end
    end
  end

  def report_exists?(%Shop{} = shop, period, now \\ DateTime.utc_now()) do
    with {:ok, period} <- normalize_period(period) do
      {starts_at, ends_at} = period_range(period, now)
      !is_nil(report_for_range(shop, period, starts_at, ends_at))
    else
      {:error, :invalid_period} -> false
    end
  end

  @doc """
  Create a report from summary data.
  """
  def create_report(%Shop{} = shop, period, starts_at, ends_at, summary) do
    %Report{}
    |> Report.changeset(
      Map.merge(summary, %{
        shop: shop.name,
        shop_id: shop.id,
        period: period,
        starts_at: starts_at,
        ends_at: ends_at,
        status: "generating"
      })
    )
    |> Repo.insert()
  end

  @doc "Generate a PDF file for a report."
  def generate_pdf(%Report{} = report) do
    report = get_report!(report.id)
    html = report_pdf_html(report)
    disk_path = report_pdf_disk_path(report)

    with {:ok, pdf_binary} <- PdfGenerator.generate_binary(html, pdf_options()),
         :ok <- File.mkdir_p(Path.dirname(disk_path)),
         :ok <- File.write(disk_path, pdf_binary),
         {:ok, updated_report} <-
           update_report(report, %{file_path: report_pdf_url(report), status: "ready"}) do
      {:ok, updated_report}
    else
      {:error, reason} ->
        _ =
          update_report(report, %{
            status: "failed",
            metadata: Map.put(report.metadata || %{}, "pdf_error", inspect(reason))
          })

        {:error, reason}

      other ->
        _ =
          update_report(report, %{
            status: "failed",
            metadata: Map.put(report.metadata || %{}, "pdf_error", inspect(other))
          })

        {:error, other}
    end
  end

  def list_reports(%Shop{} = shop, opts \\ []) do
    from(r in Report,
      where: r.shop_id == ^shop.id,
      order_by: [desc: r.inserted_at],
      limit: ^Keyword.get(opts, :limit, 20)
    )
    |> Repo.all()
    |> Enum.map(&backfill_items_sold/1)
  end

  def get_report!(id) do
    Report
    |> Repo.get!(id)
    |> Repo.preload(:shop)
    |> backfill_items_sold()
  end

  def update_report(report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
  end

  defp duplicate_daily_report?(shop, "daily", starts_at, ends_at) do
    !is_nil(report_for_range(shop, "daily", starts_at, ends_at))
  end

  defp duplicate_daily_report?(_shop, _period, _starts_at, _ends_at), do: false

  defp daily_report_constraint_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_message, opts}} ->
      opts[:constraint_name] == "reports_daily_once_per_period_index"
    end)
  end

  defp report_for_range(shop, period, starts_at, ends_at) do
    Repo.one(
      from(r in Report,
        where: r.shop_id == ^shop.id,
        where: r.period == ^period,
        where: r.starts_at == ^starts_at,
        where: r.ends_at == ^ends_at,
        limit: 1
      )
    )
  end

  defp normalize_period(period) when period in @periods, do: {:ok, period}

  defp normalize_period(period) when is_atom(period) do
    period |> Atom.to_string() |> normalize_period()
  end

  defp normalize_period(_period), do: {:error, :invalid_period}

  defp period_range("daily", now) do
    date = DateTime.to_date(now)
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    {start_of_day, end_of_day}
  end

  defp period_range("weekly", now) do
    date = DateTime.to_date(now)
    week_start = Date.add(date, 1 - Date.day_of_week(date))
    week_end = Date.add(week_start, 6)

    {DateTime.new!(week_start, ~T[00:00:00], "Etc/UTC"),
     DateTime.new!(week_end, ~T[23:59:59], "Etc/UTC")}
  end

  defp period_range("monthly", now) do
    date = DateTime.to_date(now)
    month_start = %{date | day: 1}
    month_end = Date.end_of_month(date)

    {DateTime.new!(month_start, ~T[00:00:00], "Etc/UTC"),
     DateTime.new!(month_end, ~T[23:59:59], "Etc/UTC")}
  end

  defp revenue_for_channel(orders, channel) do
    orders
    |> Enum.filter(&(&1.channel == channel))
    |> Enum.reduce(Decimal.new("0"), &Decimal.add(&2, &1.total || 0))
  end

  defp total_items_count(orders) do
    orders
    |> Enum.flat_map(& &1.items)
    |> Enum.reduce(0, fn item, acc -> acc + item.quantity end)
  end

  defp items_sold_summary(orders) do
    orders
    |> Enum.flat_map(fn order ->
      Enum.map(order.items, fn item ->
        %{
          product_id: item.product_id,
          product_name: item.product_name,
          quantity: item.quantity || 0,
          revenue: item.line_total || Decimal.new("0"),
          channel: order.channel
        }
      end)
    end)
    |> Enum.group_by(&{&1.product_id, &1.product_name})
    |> Enum.map(fn {{product_id, product_name}, items} ->
      total_quantity = Enum.reduce(items, 0, &(&2 + &1.quantity))
      pos_quantity = quantity_for_channel(items, :pos)
      online_quantity = quantity_for_channel(items, :online)

      total_revenue =
        Enum.reduce(items, Decimal.new("0"), &Decimal.add(&2, &1.revenue))

      %{
        "product_id" => product_id,
        "product_name" => product_name,
        "quantity" => total_quantity,
        "pos_quantity" => pos_quantity,
        "online_quantity" => online_quantity,
        "revenue" => Decimal.to_string(total_revenue)
      }
    end)
    |> Enum.sort_by(& &1["quantity"], :desc)
  end

  defp quantity_for_channel(items, channel) do
    items
    |> Enum.filter(&(&1.channel == channel))
    |> Enum.reduce(0, &(&2 + &1.quantity))
  end

  defp pdf_options do
    [page_size: "A4", delete_temporary: true]
  end

  defp report_pdf_url(report), do: "/reports/report-#{report.id}.pdf"

  defp report_pdf_disk_path(report) do
    report_pdf_url(report)
    |> String.trim_leading("/")
    |> then(&Path.join(web_static_reports_dir(), &1))
  end

  defp web_static_reports_dir do
    Path.join([:code.priv_dir(:smart_kiosk_web) |> to_string(), "static"])
  end

  defp report_pdf_html(report) do
    items_html =
      report_items(report)
      |> Enum.map_join("\n", fn item ->
        """
        <tr>
          <td>#{item["product_name"]}</td>
          <td style="text-align:right">#{item["quantity"]}</td>
          <td style="text-align:right">#{item["pos_quantity"] || 0}</td>
          <td style="text-align:right">#{item["online_quantity"] || 0}</td>
          <td style="text-align:right">KES #{item["revenue"]}</td>
        </tr>
        """
      end)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8" />
      <style>
        body { font-family: Arial, sans-serif; color: #111827; padding: 28px; }
        h1 { margin: 0 0 8px; font-size: 28px; }
        .meta { color: #4b5563; font-size: 12px; margin-bottom: 18px; }
        .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 18px 0 24px; }
        .card { border: 1px solid #e5e7eb; border-radius: 10px; padding: 12px; }
        .card .label { font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: .08em; }
        .card .value { font-size: 18px; font-weight: 700; margin-top: 4px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { border-bottom: 1px solid #e5e7eb; padding: 10px 8px; font-size: 12px; }
        th { text-align: left; color: #374151; background: #f9fafb; }
        td:nth-child(2), td:nth-child(3), td:nth-child(4), td:nth-child(5) { white-space: nowrap; }
        .muted { color: #6b7280; font-size: 12px; }
      </style>
    </head>
    <body>
      <h1>#{if report.shop, do: report.shop.name, else: "Shop"},
       #{report.period |> String.capitalize()} Sales Report</h1>
      <div class="meta">
        Period: #{Calendar.strftime(report.starts_at, "%d %b %Y %H:%M")} -
        #{Calendar.strftime(report.ends_at, "%d %b %Y %H:%M")}
      </div>
      <div class="summary">
        <div class="card"><div class="label">Revenue</div><div class="value">KES #{decimal_text(report.total_revenue)}</div></div>
        <div class="card"><div class="label">Orders</div><div class="value">#{report.total_orders}</div></div>
        <div class="card"><div class="label">POS</div><div class="value">#{report.pos_orders || 0}</div><div class="muted">KES #{metadata_decimal(report, "pos_revenue")}</div></div>
        <div class="card"><div class="label">Online</div><div class="value">#{report.online_orders || 0}</div><div class="muted">KES #{metadata_decimal(report, "online_revenue")}</div></div>
      </div>
      <h2 style="margin: 0 0 10px; font-size: 18px;">Items Sold</h2>
      <table>
        <thead>
          <tr>
            <th>Item</th>
            <th style="text-align:right">Qty</th>
            <th style="text-align:right">POS</th>
            <th style="text-align:right">Online</th>
            <th style="text-align:right">Revenue</th>
          </tr>
        </thead>
        <tbody>
          #{if items_html == "", do: "<tr><td colspan=\"5\" class=\"muted\">No items sold in this period.</td></tr>", else: items_html}
        </tbody>
      </table>
    </body>
    </html>
    """
  end

  defp report_items(%Report{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, "items_sold") do
      items when is_list(items) -> items
      _ -> []
    end
  end

  defp report_items(_report), do: []

  defp metadata_decimal(%Report{metadata: metadata}, key) when is_map(metadata) do
    metadata
    |> Map.get(key, "0")
    |> decimal_text()
  end

  defp metadata_decimal(_report, _key), do: "0.00"

  defp decimal_text(%Decimal{} = value), do: Decimal.to_string(value)
  defp decimal_text(value) when is_binary(value), do: value

  defp decimal_text(value) when is_number(value),
    do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  defp decimal_text(_), do: "0.00"

  defp backfill_items_sold(%Report{metadata: %{"items_sold" => items_sold}} = report)
       when is_list(items_sold) do
    if valid_items_sold?(items_sold, report.total_items) do
      report
    else
      rebuild_items_sold(report)
    end
  end

  defp backfill_items_sold(%Report{} = report), do: rebuild_items_sold(report)

  defp rebuild_items_sold(%Report{} = report) do
    items_sold =
      report.shop_id
      |> orders_for_range(report.starts_at, report.ends_at)
      |> items_sold_summary()

    metadata =
      report.metadata
      |> Kernel.||(%{})
      |> Map.put("items_sold", items_sold)

    %{report | metadata: metadata}
  end

  defp valid_items_sold?([], total_items) when total_items not in [nil, 0], do: false

  defp valid_items_sold?(items_sold, _total_items) do
    Enum.all?(items_sold, fn item ->
      is_binary(item["product_name"]) and item["product_name"] != ""
    end)
  end

  defp orders_for_range(shop_id, starts_at, ends_at) do
    from(o in Order,
      where: o.shop_id == ^shop_id,
      where: o.status != :cancelled,
      where: o.inserted_at >= ^starts_at and o.inserted_at <= ^ends_at,
      preload: [:items]
    )
    |> Repo.all()
  end
end
