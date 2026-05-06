defmodule SmartKioskWeb.PageController do
  use SmartKioskWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
