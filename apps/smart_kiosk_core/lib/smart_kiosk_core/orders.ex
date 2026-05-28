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
  alias SmartKioskCore.Schemas.{Customer, Order, OrderItem, Product, Shop, Transaction}
  alias SmartKioskCore.{Catalogue, Cart, Deliveries}

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

  @doc "Counts orders grouped by status for a shop."
  def count_orders_by_status(%Shop{} = shop) do
    Order
    |> scope(shop)
    |> group_by([o], o.status)
    |> select([o], {o.status, count(o.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Gets a single order, scoped to a shop."
  def get_order!(%Shop{} = shop, id) do
    Order
    |> scope(shop)
    |> preload([:customer, delivery: [:rider], items: :product, transactions: []])
    |> Repo.get!(id)
  end

  # =======================Order ACTIONS===========================================
  # =======get pending orders================
  def get_pending_orders(%Shop{} = shop) do
    Order
    |> scope(shop)
    |> where([o], o.status == :pending)
    |> Repo.all()
  end

  @doc """
  Updates the status of a specific order within a shop.
  """
  def update_order_status(%Shop{} = shop, order_id, status) when is_atom(status) do
    Order
    |> scope(shop)
    |> where([o], o.id == ^order_id)
    |> Repo.update_all(set: [status: status])
  end

  # ==================================================================================

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
    delivery_type = delivery_attr(delivery_attrs, :delivery_type) || :delivery

    delivery_type =
      case delivery_type do
        "pickup" -> :pickup
        "delivery" -> :delivery
        atom when is_atom(atom) -> atom
        _ -> :delivery
      end

    delivery_attrs = Map.put(delivery_attrs, :delivery_type, delivery_type)

    with {:ok, delivery_attrs, selected_zone} <-
           prepare_order_delivery(shop, channel, delivery_type, delivery_attrs) do
      Repo.transaction(fn ->
        scoped_items = load_scoped_items!(shop, items)

        # 1. Build line items with snapshotted prices
        line_items =
          Enum.map(scoped_items, fn {product, qty} ->
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

        delivery_fee =
          if delivery_type == :pickup,
            do: Decimal.new("0"),
            else: (selected_zone && selected_zone.base_fee) || Decimal.new("0")

        delivery_address = delivery_attr(delivery_attrs, :delivery_address)
        delivery_lat = delivery_attr(delivery_attrs, :delivery_lat)
        delivery_lng = delivery_attr(delivery_attrs, :delivery_lng)
        delivery_zone_id = delivery_attr(delivery_attrs, :delivery_zone_id)

        # 2. Create order
        order_attrs =
          %{
            shop_id: shop.id,
            customer_id: customer_id,
            channel: channel,
            delivery_type: delivery_type,
            notes: notes,
            subtotal: subtotal,
            delivery_fee: delivery_fee,
            status: :pending
          }
          |> maybe_put_delivery(:delivery_address, delivery_address)
          |> maybe_put_delivery(:delivery_lat, delivery_lat)
          |> maybe_put_delivery(:delivery_lng, delivery_lng)
          |> maybe_put_delivery(:delivery_zone_id, delivery_zone_id)

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
        stock_items = Enum.map(scoped_items, fn {product, qty} -> {product, -qty} end)
        Catalogue.adjust_stock_bulk(stock_items) |> ok_or_rollback()

        case maybe_create_delivery(order, shop, channel, delivery_attrs) do
          {:ok, _delivery} ->
            :ok

          {:error, reason} ->
            Repo.rollback(reason)
        end

        order =
          order
          |> Repo.preload([
            :customer,
            :shop,
            delivery: [:rider, :delivery_zone],
            items: :product,
            transactions: []
          ])

        # 5. Broadcast
        broadcast_order_event(shop, {:new_order, order})

        order
      end)
    end
  end

  defp maybe_create_delivery(_order, _shop, channel, _delivery_attrs) when channel != :online do
    {:ok, nil}
  end

  defp maybe_create_delivery(order, shop, _channel, delivery_attrs) do
    delivery_type = delivery_attr(delivery_attrs, :delivery_type) || :delivery

    require Logger

    Logger.debug(
      "maybe_create_delivery: delivery_type=#{inspect(delivery_type)}, delivery_attrs=#{inspect(delivery_attrs)}"
    )

    if delivery_type == :pickup do
      {:ok, nil}
    else
      case Deliveries.create_delivery_for_order(order, shop, delivery_attrs) do
        {:ok, delivery} ->
          Logger.debug("maybe_create_delivery: delivery created successfully")
          {:ok, delivery}

        {:error, reason} ->
          Logger.error(
            "maybe_create_delivery: failed to create delivery, reason=#{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  defp prepare_order_delivery(_shop, channel, _delivery_type, delivery_attrs)
       when channel != :online do
    {:ok, delivery_attrs, nil}
  end

  defp prepare_order_delivery(%Shop{} = _shop, _channel, :pickup, delivery_attrs) do
    # For pickup orders, skip delivery preparation
    {:ok, delivery_attrs, nil}
  end

  defp prepare_order_delivery(%Shop{} = shop, _channel, :delivery, delivery_attrs) do
    case Deliveries.prepare_delivery_point(shop, delivery_attrs) do
      {:ok, zone, lat, lng} ->
        prepared_attrs =
          delivery_attrs
          |> put_delivery_point(:delivery_zone_id, zone.id)
          |> put_delivery_point(:delivery_lat, lat)
          |> put_delivery_point(:delivery_lng, lng)

        {:ok, prepared_attrs, zone}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_delivery_point(attrs, key, value) do
    if Map.has_key?(attrs, key) do
      Map.put(attrs, key, value)
    else
      Map.put(attrs, Atom.to_string(key), value)
    end
  end

  defp delivery_attr(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp maybe_put_delivery(attrs, _key, nil), do: attrs
  defp maybe_put_delivery(attrs, key, value), do: Map.put(attrs, key, value)

  @doc """
  Processes a POS payment: creates an order, records a transaction, and optionally clears the cart.

  Accepts:
    - shop: %Shop{}
    - items: list of {%Product{}, quantity}
    - payment_attrs: %{payment_method: :cash|:mpesa_stk|:card, amount: decimal, user_id: cashier_id, ...}
    - opts:
        - user: %User{} (to clear cart)
        - session_id: string (to clear cart)
        - clear_cart: boolean

  Returns {:ok, %{order: order, transaction: transaction}} or {:error, reason}.
  """
  def process_pos_payment(%Shop{} = shop, items, payment_attrs, opts \\ []) do
    Repo.transaction(fn ->
      # 1. Create the order (this handles stock deduction and broadcasting)
      order =
        case create_order(shop, items, Keyword.put(opts, :channel, :pos)) do
          {:ok, order} -> order
          {:error, reason} -> Repo.rollback(reason)
        end

      # 2. Prepare transaction attributes
      # For now, cash is completed immediately, others start as pending
      txn_status = if payment_attrs[:payment_method] == :cash, do: :completed, else: :pending

      txn_attrs =
        payment_attrs
        |> Map.merge(%{
          shop_id: shop.id,
          order_id: order.id,
          type: :pos_payment,
          status: txn_status,
          currency: payment_attrs[:currency] || "KES"
        })

      # 3. Insert transaction
      transaction =
        %Transaction{}
        |> Transaction.changeset(txn_attrs)
        |> Repo.insert()
        |> case do
          {:ok, txn} -> txn
          {:error, changeset} -> Repo.rollback(changeset)
        end

      # 4. Clear cart if requested
      if opts[:clear_cart] do
        case {opts[:user], opts[:session_id]} do
          {%SmartKioskCore.Schemas.User{} = user, _} ->
            Cart.clear_user_cart(user)

          {_, session_id} when is_binary(session_id) ->
            Cart.clear_session_cart(session_id)

          _ ->
            :ok
        end
      end

      %{order: order, transaction: transaction}
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

  @doc """
  Finds or creates a customer by phone for a shop.

  If an existing customer has no `user_id` and one is provided in `attrs`,
  the record is updated so that order history can be tied back to the
  platform user for personalization.
  """
  def find_or_create_customer(%Shop{} = shop, attrs) do
    phone = attrs[:phone]
    user_id = attrs[:user_id]

    case Repo.get_by(Customer, shop_id: shop.id, phone: phone) do
      nil ->
        %Customer{}
        |> Customer.changeset(Map.put(attrs, :shop_id, shop.id))
        |> Repo.insert()

      %Customer{user_id: nil} = customer when not is_nil(user_id) ->
        customer
        |> Customer.changeset(%{user_id: user_id})
        |> Repo.update()

      customer ->
        {:ok, customer}
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────────────

  defp ok_or_rollback({:ok, val}), do: {:ok, val}
  defp ok_or_rollback({:error, reason}), do: Repo.rollback(reason)

  defp load_scoped_items!(%Shop{} = shop, items) when is_list(items) do
    if items == [] do
      Repo.rollback(:invalid_cart)
    end

    extracted_items =
      Enum.map(items, fn
        {%{id: id}, qty} when is_binary(id) and is_integer(qty) and qty > 0 ->
          {id, qty}

        _ ->
          Repo.rollback(:invalid_cart)
      end)

    product_ids = Enum.map(extracted_items, &elem(&1, 0))

    if length(Enum.uniq(product_ids)) != length(product_ids) do
      Repo.rollback({:invalid_cart, :duplicate_products})
    end

    products_by_id =
      Product
      |> scope(shop)
      |> where([p], p.id in ^product_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.map(extracted_items, fn {product_id, qty} ->
      case Map.get(products_by_id, product_id) do
        nil ->
          Repo.rollback({:invalid_product, product_id})

        %Product{stock_qty: stock_qty} = product when stock_qty < qty ->
          Repo.rollback({:insufficient_stock, product.id})

        %Product{} = product ->
          {product, qty}
      end
    end)
  end

  defp filter_order_status(query, nil), do: query
  defp filter_order_status(query, s), do: where(query, [o], o.status == ^s)

  defp filter_order_channel(query, nil), do: query
  defp filter_order_channel(query, c), do: where(query, [o], o.channel == ^c)

  defp broadcast_order_event(%Shop{id: shop_id}, event) do
    Phoenix.PubSub.broadcast(SmartKiosk.PubSub, "shop:#{shop_id}:orders", event)
  end
end
