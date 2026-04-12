defmodule EuropaWeb.AuthorizedOnly do
  use EuropaWeb, :verified_routes

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
    else
      conn
      |> Phoenix.Controller.redirect(to: ~p"/users/register")
      |> halt()
    end
  end
end
