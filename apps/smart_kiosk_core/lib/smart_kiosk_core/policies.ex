defimpl Canada.Can, for: SmartKioskCore.Schemas.User do
  alias SmartKioskCore.Authorization
  alias SmartKioskCore.Schemas.Shop

  # Platform-level checks (no shop scope)
  def can?(user, action, nil) when is_atom(action) do
    Authorization.can?(user, to_slug(action))
  end

  # Shop-scoped checks
  def can?(user, action, %Shop{} = shop) when is_atom(action) do
    Authorization.can?(user, to_slug(action), shop)
  end

  # action atom → "resource:action" slug
  defp to_slug(:manage_shops),      do: "platform:manage_shops"
  defp to_slug(:manage_users),      do: "platform:manage_users"
  defp to_slug(:platform_read),     do: "platform:read"
  defp to_slug(:manage_settings),   do: "shop:manage_settings"
  defp to_slug(:manage_staff),      do: "shop:manage_staff"
  defp to_slug(:read_orders),       do: "orders:read"
  defp to_slug(:write_orders),      do: "orders:write"
  defp to_slug(:cancel_orders),     do: "orders:cancel"
  defp to_slug(:read_inventory),    do: "inventory:read"
  defp to_slug(:write_inventory),   do: "inventory:write"
  defp to_slug(:read_customers),    do: "customers:read"
  defp to_slug(:write_customers),   do: "customers:write"
  defp to_slug(:use_pos),           do: "pos:use"
  defp to_slug(:read_analytics),    do: "analytics:read"
  defp to_slug(:read_campaigns),    do: "campaigns:read"
  defp to_slug(:write_campaigns),   do: "campaigns:write"
  defp to_slug(:read_deliveries),   do: "deliveries:read"
  defp to_slug(:manage_deliveries), do: "deliveries:manage"
  defp to_slug(:read_transactions), do: "transactions:read"
end
