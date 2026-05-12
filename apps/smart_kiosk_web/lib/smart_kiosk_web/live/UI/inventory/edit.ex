defmodule SmartKioskWeb.Inventory.Edit do
  use SmartKioskWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Edit Product")}
  end
end
