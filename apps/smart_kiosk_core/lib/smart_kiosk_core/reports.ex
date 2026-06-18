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

    %{
      total_orders: total_orders,
      total_revenue: total_revenue,
      total_items: total_items,
      online_orders: online_orders,
      pos_orders: pos_orders,
      metadata: %{
        "online_revenue" => Decimal.to_string(online_revenue),
        "pos_revenue" => Decimal.to_string(pos_revenue),
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
      summary = generate_sales_summary(shop, starts_at, ends_at)

      create_report(shop, period, starts_at, ends_at, summary)
    end
  end

  @doc """
  Create a report from summary data.
  """
  def create_report(%Shop{} = shop, period, starts_at, ends_at, summary) do
    %Report{}
    |> Report.changeset(
      Map.merge(summary, %{
        shop_id: shop.id,
        period: period,
        starts_at: starts_at,
        ends_at: ends_at,
        status: "ready"
      })
    )
    |> Repo.insert()
  end

  @doc "Generate a PDF file for a report (async via Oban)"
  def generate_pdf(report) do
    # Placeholder until PDF rendering is wired to the worker.
    {:ok, _} = update_report(report, %{file_path: "/reports/#{report.id}.pdf"})
  end

  def list_reports(%Shop{} = shop, opts \\ []) do
    from(r in Report,
      where: r.shop_id == ^shop.id,
      order_by: [desc: r.inserted_at],
      limit: ^Keyword.get(opts, :limit, 20)
    )
    |> Repo.all()
  end

  def get_report!(id), do: Repo.get!(Report, id)

  def update_report(report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
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
end
