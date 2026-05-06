defmodule SmartKioskCore.Schemas.Order do
  @moduledoc """
  An order placed either via POS (channel: :pos) or the online storefront
  (channel: :online).

  Status lifecycle:
    :pending → :confirmed → :preparing → :ready → :dispatched → :delivered
    Any status → :cancelled

  Prices are snapshotted at order creation time — product price changes
  do not affect existing orders.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses  ~w(pending confirmed preparing ready dispatched delivered cancelled)a
  @channels  ~w(pos online)a

  schema "orders" do
    field :status,           Ecto.Enum, values: @statuses, default: :pending
    field :channel,          Ecto.Enum, values: @channels, default: :online
    field :subtotal,         :decimal
    field :delivery_fee,     :decimal, default: Decimal.new("0")
    field :total,            :decimal
    field :notes,            :string
    field :delivery_address, :string
    field :delivery_lat,     :float
    field :delivery_lng,     :float

    belongs_to :shop,     SmartKioskCore.Schemas.Shop
    belongs_to :customer, SmartKioskCore.Schemas.Customer

    has_many :items,        SmartKioskCore.Schemas.OrderItem
    has_one  :delivery,     SmartKioskCore.Schemas.Delivery
    has_many :transactions, SmartKioskCore.Schemas.Transaction

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id channel)a
  @optional ~w(customer_id status subtotal delivery_fee total notes delivery_address delivery_lat delivery_lng)a

  def changeset(order, attrs) do
    order
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:customer_id)
    |> compute_total()
  end

  @doc "Transition the order status."
  def status_changeset(order, new_status) do
    order
    |> change(status: new_status)
    |> validate_inclusion(:status, Ecto.Enum.values(__MODULE__, :status))
  end

  defp compute_total(%Ecto.Changeset{} = cs) do
    subtotal     = get_field(cs, :subtotal)     || Decimal.new("0")
    delivery_fee = get_field(cs, :delivery_fee) || Decimal.new("0")

    if subtotal do
      put_change(cs, :total, Decimal.add(subtotal, delivery_fee))
    else
      cs
    end
  end
end

defmodule SmartKioskCore.Schemas.OrderItem do
  @moduledoc """
  A line item on an order. Prices are snapshotted from the product at the
  time the order is placed — never joined back to the live product price.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_items" do
    field :quantity,    :integer
    field :unit_price,  :decimal
    field :line_total,  :decimal

    # product_name snapshot — survives product rename/deletion
    field :product_name, :string

    belongs_to :order,   SmartKioskCore.Schemas.Order
    belongs_to :product, SmartKioskCore.Schemas.Product

    timestamps(type: :utc_datetime)
  end

  @required ~w(order_id product_id quantity unit_price product_name)a

  def changeset(item, attrs) do
    item
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> compute_line_total()
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:product_id)
  end

  defp compute_line_total(cs) do
    qty   = get_change(cs, :quantity)
    price = get_change(cs, :unit_price)

    if qty && price do
      put_change(cs, :line_total, Decimal.mult(Decimal.new(qty), price))
    else
      cs
    end
  end
end

defmodule SmartKioskCore.Schemas.Transaction do
  @moduledoc """
  Financial transaction record. Covers:
    - POS payments (type: :pos_payment)
    - Online order payments (type: :order_payment)
    - Refunds (type: :refund)
    - Delivery fee charges (type: :delivery_charge)
    - Subscription payments (type: :subscription_payment)

  Payment methods:
    :mpesa_stk   — M-PESA STK Push
    :mpesa_qr    — M-PESA QR scan (Till/PayBill)
    :card        — Card via gateway
    :cash        — Cash in hand

  Status: :pending | :completed | :failed | :refunded
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types   ~w(pos_payment order_payment refund delivery_charge subscription_payment)a
  @methods ~w(mpesa_stk mpesa_qr card cash)a
  @statuses ~w(pending completed failed refunded)a

  schema "transactions" do
    field :type,           Ecto.Enum, values: @types
    field :amount,         :decimal
    field :currency,       :string, default: "KES"
    field :payment_method, Ecto.Enum, values: @methods
    field :status,         Ecto.Enum, values: @statuses, default: :pending
    field :reference,      :string   # M-PESA checkout request ID, card charge ID, etc.
    field :metadata,       :map, default: %{}  # gateway-specific payload

    belongs_to :shop,  SmartKioskCore.Schemas.Shop
    belongs_to :user,  SmartKioskCore.Schemas.User   # cashier who processed it
    belongs_to :order, SmartKioskCore.Schemas.Order   # nullable for walk-in POS sales

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id type amount payment_method)a
  @optional ~w(user_id order_id currency status reference metadata)a

  def changeset(txn, attrs) do
    txn
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency, is: 3)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:order_id)
  end

  @doc "Mark a transaction completed with a gateway reference."
  def complete_changeset(txn, reference) do
    change(txn, status: :completed, reference: reference)
  end

  @doc "Mark a transaction failed."
  def fail_changeset(txn, reason) do
    change(txn, status: :failed, metadata: Map.put(txn.metadata, "failure_reason", reason))
  end
end
