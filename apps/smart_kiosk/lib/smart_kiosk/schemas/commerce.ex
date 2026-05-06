defmodule SmartKioskCore.Schemas.Delivery do
  @moduledoc """
  A delivery task linked to an order. Assigned to a rider within a zone.

  Status: :pending_pickup | :picked_up | :in_transit | :delivered | :failed
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending_pickup picked_up in_transit delivered failed)a

  schema "deliveries" do
    field :status,        Ecto.Enum, values: @statuses, default: :pending_pickup
    field :pickup_lat,    :float
    field :pickup_lng,    :float
    field :dropoff_lat,   :float
    field :dropoff_lng,   :float
    field :distance_km,   :decimal
    field :notes,         :string
    field :picked_up_at,  :utc_datetime
    field :delivered_at,  :utc_datetime

    belongs_to :order,         SmartKioskCore.Schemas.Order
    belongs_to :rider,         SmartKioskCore.Schemas.Rider
    belongs_to :delivery_zone, SmartKioskCore.Schemas.DeliveryZone

    timestamps(type: :utc_datetime)
  end

  @required ~w(order_id pickup_lat pickup_lng dropoff_lat dropoff_lng)a
  @optional ~w(rider_id delivery_zone_id status distance_km notes picked_up_at delivered_at)a

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:rider_id)
    |> foreign_key_constraint(:delivery_zone_id)
  end

  def status_changeset(delivery, :picked_up) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(delivery, status: :picked_up, picked_up_at: now)
  end

  def status_changeset(delivery, :delivered) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(delivery, status: :delivered, delivered_at: now)
  end

  def status_changeset(delivery, new_status) do
    change(delivery, status: new_status)
  end
end

defmodule SmartKioskCore.Schemas.Campaign do
  @moduledoc """
  An advertising campaign belonging to a shop.

  `target_type`: :geo | :category | :keyword
  `targeting`: JSONB — shape depends on target_type:
    geo:      %{"radius_km" => 5, "lat" => -1.28, "lng" => 36.82}
    category: %{"category_ids" => ["uuid1", "uuid2"]}
    keyword:  %{"keywords" => ["groceries", "fresh milk"]}

  Status: :draft | :active | :paused | :ended | :budget_exhausted
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @target_types ~w(geo category keyword)a
  @statuses     ~w(draft active paused ended budget_exhausted)a

  schema "campaigns" do
    field :name,        :string
    field :status,      Ecto.Enum, values: @statuses, default: :draft
    field :target_type, Ecto.Enum, values: @target_types
    field :targeting,   :map, default: %{}
    field :budget,      :decimal
    field :spent,       :decimal, default: Decimal.new("0")
    field :cpc,         :decimal    # cost per click, in KES
    field :starts_at,   :utc_datetime
    field :ends_at,     :utc_datetime

    belongs_to :shop, SmartKioskCore.Schemas.Shop

    has_many :creatives, SmartKioskCore.Schemas.AdCreative
    has_many :events,    SmartKioskCore.Schemas.AdEvent

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id name target_type budget)a
  @optional ~w(status targeting cpc starts_at ends_at)a

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 3, max: 120)
    |> validate_number(:budget, greater_than: 0)
    |> validate_number(:cpc, greater_than: 0)
    |> validate_date_range()
    |> foreign_key_constraint(:shop_id)
  end

  defp validate_date_range(cs) do
    starts = get_field(cs, :starts_at)
    ends   = get_field(cs, :ends_at)

    if starts && ends && DateTime.compare(ends, starts) != :gt do
      add_error(cs, :ends_at, "must be after start date")
    else
      cs
    end
  end
end

defmodule SmartKioskCore.Schemas.AdCreative do
  @moduledoc "An individual ad creative within a campaign."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ad_creatives" do
    field :headline,  :string
    field :body,      :string
    field :image_url, :string
    field :cta,       :string    # e.g. "Shop Now", "Order Today"
    field :link_url,  :string
    field :active,    :boolean, default: true

    belongs_to :campaign, SmartKioskCore.Schemas.Campaign
    has_many   :events,   SmartKioskCore.Schemas.AdEvent

    timestamps(type: :utc_datetime)
  end

  def changeset(creative, attrs) do
    creative
    |> cast(attrs, [:headline, :body, :image_url, :cta, :link_url, :active, :campaign_id])
    |> validate_required([:headline, :campaign_id])
    |> validate_length(:headline, max: 80)
    |> validate_length(:body, max: 200)
    |> foreign_key_constraint(:campaign_id)
  end
end

defmodule SmartKioskCore.Schemas.AdEvent do
  @moduledoc """
  Append-only log of ad impressions and clicks.
  Never updated — only inserted. Aggregated nightly into summary tables (Phase 4).

  `event_type`: :impression | :click
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @event_types ~w(impression click)a

  schema "ad_events" do
    field :event_type, Ecto.Enum, values: @event_types
    field :session_id, :string    # anonymous visitor session
    field :ip_hash,    :string    # hashed for privacy

    belongs_to :campaign, SmartKioskCore.Schemas.Campaign
    belongs_to :creative, SmartKioskCore.Schemas.AdCreative
    belongs_to :shop,     SmartKioskCore.Schemas.Shop

    # No updated_at — this is an append-only log
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :session_id, :ip_hash, :campaign_id, :creative_id, :shop_id])
    |> validate_required([:event_type, :campaign_id, :creative_id, :shop_id])
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:creative_id)
    |> foreign_key_constraint(:shop_id)
  end
end

defmodule SmartKioskCore.Schemas.Subscription do
  @moduledoc """
  A shop's current subscription plan. One subscription per shop.

  `plan`: :kiosk | :duka | :biashara | :enterprise
  `status`: :trialing | :active | :past_due | :cancelled
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @plans    ~w(kiosk duka biashara enterprise)a
  @statuses ~w(trialing active past_due cancelled)a

  schema "subscriptions" do
    field :plan,                  Ecto.Enum, values: @plans, default: :kiosk
    field :status,                Ecto.Enum, values: @statuses, default: :trialing
    field :current_period_start,  :utc_datetime
    field :current_period_end,    :utc_datetime
    field :trial_ends_at,         :utc_datetime
    field :cancelled_at,          :utc_datetime

    belongs_to :shop,     SmartKioskCore.Schemas.Shop
    has_many   :invoices, SmartKioskCore.Schemas.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [:plan, :status, :current_period_start, :current_period_end,
                    :trial_ends_at, :cancelled_at, :shop_id])
    |> validate_required([:shop_id, :plan])
    |> foreign_key_constraint(:shop_id)
    |> unique_constraint(:shop_id, message: "shop already has a subscription")
  end
end

defmodule SmartKioskCore.Schemas.Invoice do
  @moduledoc """
  Billing invoice for a subscription period.
  `status`: :draft | :open | :paid | :void | :uncollectible
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft open paid void uncollectible)a

  schema "invoices" do
    field :amount,   :decimal
    field :currency, :string, default: "KES"
    field :status,   Ecto.Enum, values: @statuses, default: :draft
    field :due_at,   :utc_datetime
    field :paid_at,  :utc_datetime

    belongs_to :shop,         SmartKioskCore.Schemas.Shop
    belongs_to :subscription, SmartKioskCore.Schemas.Subscription

    timestamps(type: :utc_datetime)
  end

  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [:amount, :currency, :status, :due_at, :paid_at, :shop_id, :subscription_id])
    |> validate_required([:amount, :shop_id, :subscription_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:subscription_id)
  end
end
