defmodule SmartKioskWeb.UI.SettingsLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Schemas.Shop
  alias SmartKioskCore.Shops

  @impl true
  def mount(_params, _session, socket) do
    shop = socket.assigns.current_shop

    categories =
      Shop.category_labels()
      |> Enum.map(fn {k, v} -> {v, k} end)

    form = to_form(Shop.changeset(shop, %{}), as: "shop")

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:form, form)
     |> assign(:categories, categories)}
  end

  @impl true
  def handle_event("validate", %{"shop" => shop_params}, socket) do
    shop = socket.assigns.current_shop

    changeset = Shop.changeset(shop, shop_params)

    {:noreply, socket |> assign(:form, to_form(changeset, as: "shop", action: :validate))}
  end

  @impl true
  def handle_event("save", %{"shop" => shop_params}, socket) do
    shop = socket.assigns.current_shop

    case Shops.update_shop(shop, shop_params) do
      {:ok, updated_shop} ->
        {:noreply,
         socket
         |> put_flash(:info, "Shop profile updated successfully.")
         |> assign(:form, to_form(Shop.changeset(updated_shop, %{}), as: "shop"))}

      {:error, changeset} ->
        {:noreply, socket |> assign(:form, to_form(changeset, as: "shop"))}
    end
  end
end
