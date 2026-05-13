defmodule SmartKioskWeb.UI.Inventory.InventoryLive.Index do
  alias SmartKioskCore.Catalogue
  use SmartKioskWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    shop = socket.assigns.current_shop
    products = Catalogue.list_products(shop)

    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:page_title, "Inventory")
     |> assign(:edit_product, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # or params["id"] if you used "/inventory/#{id}/edit"
    edit_id = params["edit"]
    shop = socket.assigns.current_shop

    edit_product =
      if edit_id do
        case Catalogue.get_product!(shop, edit_id) do
          nil -> nil
          product -> product
        end
      else
        nil
      end

    {:noreply, assign(socket, edit_product: edit_product)}
  end

  # handlers for adding items to inventory
  @impl true
  def handle_event("add_product", %{"product" => product_params}, socket) do
    shop = socket.assigns.current_shop

    case Catalogue.create_product(shop, product_params) do
      {:ok, new_product} ->
        updated_products = [new_product | socket.assigns.products]

        {:noreply,
         socket
         |> assign(:products, updated_products)
         |> put_flash(:info, "Product \"#{new_product.name}\" added seccessfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> put_flash(:error, inspect(changeset))}
    end
  end

  @impl true
  # removing the product
  def handle_event("archive_product", %{"product_id" => product_id}, socket) do
    shop = socket.assigns.current_shop

    case Catalogue.get_product!(shop, product_id) do
      product ->
        case Catalogue.archive_product(product) do
          {:ok, _archived_product} ->
            updated_products =
              Enum.reject(socket.assigns.products, fn p -> p.id == product_id end)

            {:noreply,
             socket
             |> assign(:products, updated_products)
             |> put_flash(:info, "Product archived successfully!")}

          {:error, reason} ->
            {:noreply,
             socket |> put_flash(:error, "Failed to archive product: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  # open edit modal
  def handle_event("edit_product", %{"product_id" => product_id}, socket) do
    shop = socket.assigns.current_shop
    product = Catalogue.get_product!(shop, product_id)

    {:noreply,
     socket
     |> assign(:edit_product, product)
     |> push_patch(to: ~p"/inventory/?edit=#{product_id}")}
  end

  @impl true
  # close edit modal
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_product, nil)
     |> push_patch(to: ~p"/inventory")}
  end

  @impl true
  # handle product updated from modal
  def handle_info({:product_updated, _product_id}, socket) do
    shop = socket.assigns.current_shop
    products = Catalogue.list_products(shop)
    {:noreply, socket |> assign(:products, products) |> assign(:edit_product, nil)}
  end
end
