defmodule SmartKioskWeb.UI.Inventory.InventoryLive.New do
  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Product
  use SmartKioskWeb, :live_view

  def mount(_params, _session, socket) do
    shop = socket.assigns.current_shop
    changeset = Product.changeset(%Product{shop_id: shop.id}, %{})
    form = to_form(changeset, as: "product")
    categories = Catalogue.list_categories()

    {:ok,
     socket
     |> assign(:page_title, "New Product")
     |> assign(:shop, shop)
     |> assign(:form, form)
     |> assign(:categories, categories)
     |> allow_upload(:images, accept: ~w(.jpg .jpeg .png), max_entries: 5)}
  end

  def handle_event("validate", %{"product" => product_params}, socket) do
    shop = socket.assigns.shop

    changeset =
      %Product{shop_id: shop.id}
      |> Product.changeset(product_params)
      |> Map.put(:action, :validate)

    form = to_form(changeset, as: "product")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    shop = socket.assigns.shop

    case Catalogue.create_product(shop, product_params) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully!")
         |> push_navigate(to: ~p"/inventory")}

      {:error, changeset} ->
        form = to_form(changeset, as: "product", action: :insert)
        {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/inventory")}
  end
end
