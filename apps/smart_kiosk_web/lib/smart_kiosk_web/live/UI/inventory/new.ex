defmodule SmartKioskWeb.Inventory.New do
  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Product
  use SmartKioskWeb, :live_view

  def mount(_params, _session, socket) do
    shop = socket.assigns.current_shop

    changeset = Product.changeset(%Product{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "New Product")
     |> assign(:shop, shop)
     |> assign(:changeset, changeset)
     |> assign(:categories, Catalogue.list_categories())}
  end

  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      %Product{}
      |> Product.changeset(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    shop = socket.assigns.shop

    case Catalogue.create_product(shop, product_params) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully!")
         |> push_navigate(to: ~p"/inventory")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/inventory")}
  end
end
