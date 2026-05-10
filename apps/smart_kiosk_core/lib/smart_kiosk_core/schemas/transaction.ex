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

  @types ~w(pos_payment order_payment refund delivery_charge subscription_payment)a
  @methods ~w(mpesa_stk mpesa_qr card cash)a
  @statuses ~w(pending completed failed refunded)a

  schema "transactions" do
    field(:type, Ecto.Enum, values: @types)
    field(:amount, :decimal)
    field(:currency, :string, default: "KES")
    field(:payment_method, Ecto.Enum, values: @methods)
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    # M-PESA checkout request ID, card charge ID, etc.
    field(:reference, :string)
    # gateway-specific payload
    field(:metadata, :map, default: %{})

    belongs_to(:shop, SmartKioskCore.Schemas.Shop)
    # cashier who processed it
    belongs_to(:user, SmartKioskCore.Schemas.User)
    # nullable for walk-in POS sales
    belongs_to(:order, SmartKioskCore.Schemas.Order)

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
