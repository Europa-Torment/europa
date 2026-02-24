defmodule EuropaWeb.PageController do
  use EuropaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
