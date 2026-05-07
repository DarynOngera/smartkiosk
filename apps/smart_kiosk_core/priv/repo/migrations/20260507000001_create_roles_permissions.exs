defmodule SmartKioskCore.Repo.Migrations.CreateRolesPermissions do
  use Ecto.Migration

  def change do
    # ── roles ────────────────────────────────────────────────────────────────────
    create table(:roles, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name,        :string, null: false
      add :slug,        :string, null: false
      add :scope,       :string, null: false  # "platform" | "shop"
      add :description, :text
      add :is_system,   :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:slug])
    create index(:roles, [:scope])

    # ── permissions ───────────────────────────────────────────────────────────────
    create table(:permissions, primary_key: false) do
      add :id,          :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :resource,    :string, null: false
      add :action,      :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:permissions, [:resource, :action])
    create index(:permissions, [:resource])

    # ── role_permissions (join: roles ↔ permissions) ──────────────────────────
    create table(:role_permissions, primary_key: false) do
      add :id,            :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :role_id,       references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:role_permissions, [:role_id, :permission_id])
    create index(:role_permissions, [:role_id])
    create index(:role_permissions, [:permission_id])

    # ── user_roles (join: users ↔ roles, optionally scoped to a shop) ─────────
    create table(:user_roles, primary_key: false) do
      add :id,      :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :shop_id, references(:shops, type: :uuid, on_delete: :delete_all)  # nullable → platform-wide

      timestamps(type: :utc_datetime)
    end

    create index(:user_roles, [:user_id])
    create index(:user_roles, [:role_id])
    create index(:user_roles, [:shop_id])

    # Partial unique indexes handle the nullable shop_id correctly.
    # A standard UNIQUE constraint treats two NULLs as non-equal, which would
    # allow duplicate platform-scoped role assignments.
    create unique_index(:user_roles, [:user_id, :role_id],
      where: "shop_id IS NULL",
      name: :user_roles_platform_unique
    )

    create unique_index(:user_roles, [:user_id, :role_id, :shop_id],
      where: "shop_id IS NOT NULL",
      name: :user_roles_shop_unique
    )
  end
end
