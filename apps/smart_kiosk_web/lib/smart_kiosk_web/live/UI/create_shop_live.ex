defmodule SmartKioskWeb.UI.CreateShopLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts

  def mount(_params, _session, socket) do
    # Shop plans and categories
    plans = [Kiosk: :kiosk, Duka: :duka, Biashara: :biashara, Enterprise: :enterprise]

    categories = [
      General: :general_shop,
      Electronics: :electronics,
      Groceries: :groceries,
      Pharmacy: :pharmacy
    ]

    form =
      to_form(
        %{
          "name" => "",
          "phone" => "",
          "email" => "",
          "address" => "",
          "city" => "",
          "country" => "KE",
          "plan" => :kiosk,
          "category" => :general_shop,
          "description" => ""
        },
        as: :shop
      )

    {:ok,
     assign(socket,
       form: form,
       plans: plans,
       categories: categories,
       page_title: "Create Your Shop"
     )}
  end

  def handle_event("save", %{"shop" => shop_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.create_shop_for_user(user, shop_params) do
      {:ok, _shop, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Shop created successfully!")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
