defmodule EuropaWeb.UnauthorizedOnly do
  import Plug.Conn

  @behaviour Plug

  # coveralls-ignore-start
  @impl true
  def init(opts) do
    opts
  end

  # coveralls-ignore-stop

  @impl true
  def call(conn, _opts \\ []) do
    if conn.assigns[:current_user] do
      conn
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    else
      conn
    end
  end
end
