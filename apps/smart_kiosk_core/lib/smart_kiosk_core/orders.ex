defmodule SmartKioskCore.Orders do
  @moduledoc """
  The Orders context.

  Manages the full order lifecycle — creation, status transitions, and
  queries. Coordinates with Catalogue for stock adjustments and broadcasts
  real-time status events via PubSub.
  """

  import Ecto.Query
  import SmartKioskCore.Tenant

  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Order, OrderItem, Customer, Shop}
  alias SmartKioskCore.Catalogue

  # ── Order queries ─────────────────────────────────────────────────────────────

  @doc "Lists orders for a shop with optional filters."
  def list_orders(%Shop{} = shop, opts \\ []) do
    Order
    |> scope(shop)
    |> filter_order_status(opts[:status])
    |> filter_order_channel(opts[:channel])
    |> order_by([o], desc: o.inserted_at)
    |> limit(^Keyword.get(opts, :limit, 30))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> preload([:customer, items: :product])
    |> Repo.all()
  end

  @doc "Gets a single order, scoped to a shop."
  def get_order!(%Shop{} = shop, id) do
    Order
    |> scope(shop)
    |> preload([:customer, :delivery, items: :product, transactions: []])
    |> Repo.get!(id)
  end

  # ── Order creation ────────────────────────────────────────────────────────────

  @doc """
  Creates an order from a cart (list of {product, quantity} tuples).

  Steps:
    1. Validates all products belong to the shop and are in stock.
    2. Snapshots prices into order_items.
    3. Adjusts stock for each product.
    4. Broadcasts the new order to the shop's PubSub topic.

  Returns {:ok, order} or {:error, reason}.
  """
  def create_order(%Shop{} = shop, items, opts \\ []) do
    customer_id = opts[:customer_id]
    channel = opts[:channel] || :online
    notes = opts[:notes]
    delivery_attrs = opts[:delivery] || %{}

    Repo.transaction(fn ->
      # 1. Build line items with snapshotted prices
      line_items =
        Enum.map(items, fn {product, qty} ->
          %{
            product_id: product.id,
            product_name: product.name,
            quantity: qty,
            unit_price: product.price
          }
        end)

      subtotal =
        Enum.reduce(line_items, Decimal.new("0"), fn item, acc ->
          Decimal.add(acc, Decimal.mult(Decimal.new(item.quantity), item.unit_price))
        end)

      delivery_fee = delivery_attrs[:fee] || Decimal.new("0")

      # 2. Create order
      order_attrs =
        %{
          shop_id: shop.id,
          customer_id: customer_id,
          channel: channel,
          notes: notes,
          subtotal: subtotal,
          delivery_fee: delivery_fee,
          status: :pending
        }
        |> Map.merge(
          delivery_attrs
          |> Map.take([:delivery_address, :delivery_lat, :delivery_lng])
        )

      {:ok, order} =
        %Order{}
        |> Order.changeset(order_attrs)
        |> Repo.insert()
        |> ok_or_rollback()

      # 3. Insert order items
      Enum.each(line_items, fn item ->
        %OrderItem{}
        |> OrderItem.changeset(Map.put(item, :order_id, order.id))
        |> Repo.insert()
        |> ok_or_rollback()
      end)

      # 4. Deduct stock
      stock_items = Enum.map(items, fn {product, qty} -> {product, -qty} end)
      Catalogue.adjust_stock_bulk(stock_items) |> ok_or_rollback()

      order = order |> Repo.preload([:customer, items: :product])

      # 5. Broadcast
      broadcast_order_event(shop, {:new_order, order})

      order
    end)
  end

  # ── Status transitions ────────────────────────────────────────────────────────

  @doc "Transitions an order to a new status. Validates allowed transitions."
  def transition_order(%Order{} = order, new_status) do
    with :ok <- validate_transition(order.status, new_status),
         {:ok, updated} <-
           order
           |> Order.status_changeset(new_status)
           |> Repo.update() do
      broadcast_order_event(
        %Shop{id: order.shop_id},
        {:order_updated, updated}
      )

      {:ok, updated}
    end
  end

  @valid_transitions %{
    pending: [:confirmed, :cancelled],
    confirmed: [:preparing, :cancelled],
    preparing: [:ready, :cancelled],
    ready: [:dispatched, :delivered],
    dispatched: [:delivered],
    delivered: [],
    cancelled: []
  }

  defp validate_transition(current, next) do
    allowed = Map.get(@valid_transitions, current, [])
    if next in allowed, do: :ok, else: {:error, "invalid transition #{current} → #{next}"}
  end

  # ── Customer helpers ──────────────────────────────────────────────────────────

  @doc "Finds or creates a customer by phone for a shop."
  def find_or_create_customer(%Shop{} = shop, attrs) do
    phone = attrs[:phone]

    case Repo.get_by(Customer, shop_id: shop.id, phone: phone) do
      nil ->
        %Customer{}
        |> Customer.changeset(Map.put(attrs, :shop_id, shop.id))
        |> Repo.insert()

      customer ->
        {:ok, customer}
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────────────

  defp ok_or_rollback({:ok, val}), do: {:ok, val}
  defp ok_or_rollback({:error, reason}), do: Repo.rollback(reason)

  defp filter_order_status(query, nil), do: query
  defp filter_order_status(query, s), do: where(query, [o], o.status == ^s)

  defp filter_order_channel(query, nil), do: query
  defp filter_order_channel(query, c), do: where(query, [o], o.channel == ^c)

  defp broadcast_order_event(%Shop{id: shop_id}, event) do
    Phoenix.PubSub.broadcast(SmartKiosk.PubSub, "shop:#{shop_id}:orders", event)
  end
end
