defmodule SmartKioskCore.Tenant do
  @moduledoc """
  Row-level multi-tenancy enforcement.

  Every context that handles shop-owned data must pipe queries through
  `scope/2` before executing. This ensures tenant_id is always applied
  and no cross-tenant data leaks are possible.

  Usage in contexts:

      import SmartKioskCore.Tenant

      def list_products(%Shop{} = shop) do
        Product
        |> scope(shop)
        |> Repo.all()
      end

  For platform-admin queries (no tenant scope needed), use Repo directly
  without piping through scope/2.
  """

  import Ecto.Query

  alias SmartKioskCore.Schemas.Shop

  @doc """
  Scopes an Ecto query to a specific shop (tenant).
  Accepts either a %Shop{} struct or a shop UUID string.
  """
  @spec scope(Ecto.Queryable.t(), Shop.t() | Ecto.UUID.t()) :: Ecto.Query.t()
  def scope(queryable, %Shop{id: shop_id}), do: scope(queryable, shop_id)

  def scope(queryable, shop_id) when is_binary(shop_id) do
    from(q in queryable, where: q.shop_id == ^shop_id)
  end
end
