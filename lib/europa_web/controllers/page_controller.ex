defmodule EuropaWeb.PageController do
  use EuropaWeb, :controller

  @spec home(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def home(conn, _params) do
    render(conn, :home)
  end

  @spec lore(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def lore(conn, _params) do
    render(conn, :lore)
  end
end
