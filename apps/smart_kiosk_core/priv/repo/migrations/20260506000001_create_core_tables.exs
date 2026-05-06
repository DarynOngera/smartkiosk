defmodule SmartKioskCore.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    # ── Extensions ──────────────────────────────────────────────────────────────
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "SELECT 1"
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\"",    "SELECT 1"
    # PostGIS added in a later migration when Phase 3 delivery zones are implemented.

    # ── shops ───────────────────────────────────────────────────────────────────
    create table(:shops, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name,        :string,  null: false
      add :slug,        :string,  null: false
      add :phone,       :string
      add :email,       :citext
      add :address,     :string
      add :city,        :string
      add :country,     :string,  default: "KE", null: false
      add :lat,         :float
      add :lng,         :float
      add :plan,        :string,  default: "kiosk", null: false
      add :status,      :string,  default: "pending_review", null: false
      add :logo_url,    :string
      add :description, :text
      add :settings,    :map,     default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shops, [:slug])
    create unique_index(:shops, [:phone])
    create index(:shops, [:status])
    create index(:shops, [:plan])

    # ── users ───────────────────────────────────────────────────────────────────
    create table(:users, primary_key: false) do
      add :id,              :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,         references(:shops, type: :uuid, on_delete: :restrict)
      add :email,           :citext, null: false
      add :hashed_password, :string, null: false
      add :full_name,       :string
      add :phone,           :string
      add :role,            :string, null: false, default: "staff"
      add :confirmed_at,    :utc_datetime
      add :avatar_url,      :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:shop_id])
    create index(:users, [:role])

    # ── users_tokens (phx.gen.auth) ─────────────────────────────────────────────
    create table(:users_tokens, primary_key: false) do
      add :id,         :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id,    references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token,      :binary, null: false
      add :context,    :string, null: false
      add :sent_to,    :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    # ── categories ───────────────────────────────────────────────────────────────
    create table(:categories, primary_key: false) do
      add :id,                  :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :parent_id,           references(:categories, type: :uuid, on_delete: :restrict)
      add :name,                :string, null: false
      add :slug,                :string, null: false
      add :icon,                :string
      add :description,         :text
      add :attribute_templates, {:array, :map}, default: []
      add :position,            :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])
    create index(:categories, [:parent_id])

    # ── products ─────────────────────────────────────────────────────────────────
    create table(:products, primary_key: false) do
      add :id,                  :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,             references(:shops, type: :uuid, on_delete: :delete_all), null: false
      add :category_id,         references(:categories, type: :uuid, on_delete: :restrict)
      add :name,                :string, null: false
      add :description,         :text
      add :sku,                 :string
      add :barcode,             :string
      add :price,               :decimal, null: false
      add :cost_price,          :decimal
      add :stock_qty,           :integer, default: 0, null: false
      add :low_stock_threshold, :integer, default: 5
      add :attributes,          :map, default: %{}
      add :status,              :string, default: "draft", null: false
      add :is_featured,         :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:shop_id])
    create index(:products, [:category_id])
    create index(:products, [:status])
    create unique_index(:products, [:shop_id, :sku], where: "sku IS NOT NULL")
    # GIN index on JSONB attributes for efficient key-value filtering
    create index(:products, [:attributes], using: :gin, name: :products_attributes_gin_index)

    # ── product_images ───────────────────────────────────────────────────────────
    create table(:product_images, primary_key: false) do
      add :id,         :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false
      add :url,        :string, null: false
      add :alt_text,   :string
      add :position,   :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:product_images, [:product_id])

    # ── customers ────────────────────────────────────────────────────────────────
    create table(:customers, primary_key: false) do
      add :id,      :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id, references(:shops, type: :uuid, on_delete: :delete_all), null: false
      add :name,    :string
      add :phone,   :string
      add :email,   :citext
      add :notes,   :text

      timestamps(type: :utc_datetime)
    end

    create index(:customers, [:shop_id])
    create unique_index(:customers, [:shop_id, :phone], where: "phone IS NOT NULL")

    # ── orders ───────────────────────────────────────────────────────────────────
    create table(:orders, primary_key: false) do
      add :id,              :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,         references(:shops, type: :uuid, on_delete: :restrict), null: false
      add :customer_id,     references(:customers, type: :uuid, on_delete: :nilify_all)
      add :status,          :string, default: "pending", null: false
      add :channel,         :string, default: "online", null: false
      add :subtotal,        :decimal
      add :delivery_fee,    :decimal, default: 0
      add :total,           :decimal
      add :notes,           :text
      add :delivery_address, :string
      add :delivery_lat,    :float
      add :delivery_lng,    :float

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:shop_id])
    create index(:orders, [:customer_id])
    create index(:orders, [:status])
    create index(:orders, [:channel])
    create index(:orders, [:inserted_at])

    # ── order_items (associative: orders ↔ products) ──────────────────────────
    create table(:order_items, primary_key: false) do
      add :id,           :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :order_id,     references(:orders, type: :uuid, on_delete: :delete_all), null: false
      add :product_id,   references(:products, type: :uuid, on_delete: :nilify_all)
      add :product_name, :string, null: false   # snapshot
      add :quantity,     :integer, null: false
      add :unit_price,   :decimal, null: false  # snapshot
      add :line_total,   :decimal, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])

    # ── transactions ─────────────────────────────────────────────────────────────
    create table(:transactions, primary_key: false) do
      add :id,             :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,        references(:shops, type: :uuid, on_delete: :restrict), null: false
      add :user_id,        references(:users, type: :uuid, on_delete: :nilify_all)
      add :order_id,       references(:orders, type: :uuid, on_delete: :nilify_all)
      add :type,           :string, null: false
      add :amount,         :decimal, null: false
      add :currency,       :string, default: "KES", null: false
      add :payment_method, :string, null: false
      add :status,         :string, default: "pending", null: false
      add :reference,      :string
      add :metadata,       :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:shop_id])
    create index(:transactions, [:order_id])
    create index(:transactions, [:status])
    create index(:transactions, [:reference])
    create index(:transactions, [:inserted_at])

    # ── riders ───────────────────────────────────────────────────────────────────
    create table(:riders, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id,     references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :status,      :string, default: "offline", null: false
      add :current_lat, :float
      add :current_lng, :float
      add :vehicle,     :string
      add :rating,      :decimal, default: 5.0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:riders, [:user_id])
    create index(:riders, [:status])

    # ── delivery_zones ───────────────────────────────────────────────────────────
    create table(:delivery_zones, primary_key: false) do
      add :id,       :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name,     :string, null: false
      add :boundary, :map    # GeoJSON polygon; PostGIS geometry in Phase 3
      add :base_fee, :decimal, null: false
      add :active,   :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:delivery_zones, [:active])

    # ── deliveries ───────────────────────────────────────────────────────────────
    create table(:deliveries, primary_key: false) do
      add :id,               :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :order_id,         references(:orders, type: :uuid, on_delete: :restrict), null: false
      add :rider_id,         references(:riders, type: :uuid, on_delete: :nilify_all)
      add :delivery_zone_id, references(:delivery_zones, type: :uuid, on_delete: :nilify_all)
      add :status,           :string, default: "pending_pickup", null: false
      add :pickup_lat,       :float, null: false
      add :pickup_lng,       :float, null: false
      add :dropoff_lat,      :float, null: false
      add :dropoff_lng,      :float, null: false
      add :distance_km,      :decimal
      add :notes,            :text
      add :picked_up_at,     :utc_datetime
      add :delivered_at,     :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:deliveries, [:order_id])
    create index(:deliveries, [:rider_id])
    create index(:deliveries, [:status])

    # ── campaigns ────────────────────────────────────────────────────────────────
    create table(:campaigns, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,     references(:shops, type: :uuid, on_delete: :delete_all), null: false
      add :name,        :string, null: false
      add :status,      :string, default: "draft", null: false
      add :target_type, :string, null: false
      add :targeting,   :map, default: %{}
      add :budget,      :decimal, null: false
      add :spent,       :decimal, default: 0
      add :cpc,         :decimal
      add :starts_at,   :utc_datetime
      add :ends_at,     :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:campaigns, [:shop_id])
    create index(:campaigns, [:status])

    # ── ad_creatives ─────────────────────────────────────────────────────────────
    create table(:ad_creatives, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :campaign_id, references(:campaigns, type: :uuid, on_delete: :delete_all), null: false
      add :headline,    :string, null: false
      add :body,        :text
      add :image_url,   :string
      add :cta,         :string
      add :link_url,    :string
      add :active,      :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:ad_creatives, [:campaign_id])

    # ── ad_events (append-only log) ───────────────────────────────────────────
    create table(:ad_events, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :campaign_id, references(:campaigns, type: :uuid, on_delete: :delete_all), null: false
      add :creative_id, references(:ad_creatives, type: :uuid, on_delete: :delete_all), null: false
      add :shop_id,     references(:shops, type: :uuid, on_delete: :delete_all), null: false
      add :event_type,  :string, null: false
      add :session_id,  :string
      add :ip_hash,     :string

      # No updated_at — append-only
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:ad_events, [:campaign_id])
    create index(:ad_events, [:creative_id])
    create index(:ad_events, [:shop_id])
    create index(:ad_events, [:event_type])
    create index(:ad_events, [:inserted_at])

    # ── subscriptions ────────────────────────────────────────────────────────────
    create table(:subscriptions, primary_key: false) do
      add :id,                   :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,              references(:shops, type: :uuid, on_delete: :delete_all), null: false
      add :plan,                 :string, default: "kiosk", null: false
      add :status,               :string, default: "trialing", null: false
      add :current_period_start, :utc_datetime
      add :current_period_end,   :utc_datetime
      add :trial_ends_at,        :utc_datetime
      add :cancelled_at,         :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:shop_id])
    create index(:subscriptions, [:status])

    # ── invoices ─────────────────────────────────────────────────────────────────
    create table(:invoices, primary_key: false) do
      add :id,              :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :shop_id,         references(:shops, type: :uuid, on_delete: :restrict), null: false
      add :subscription_id, references(:subscriptions, type: :uuid, on_delete: :restrict), null: false
      add :amount,          :decimal, null: false
      add :currency,        :string, default: "KES", null: false
      add :status,          :string, default: "draft", null: false
      add :due_at,          :utc_datetime
      add :paid_at,         :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:invoices, [:shop_id])
    create index(:invoices, [:subscription_id])
    create index(:invoices, [:status])
  end
end
