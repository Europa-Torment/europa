defmodule EuropaWeb.AdminOnly do
  use EuropaWeb, :verified_routes

  alias Europa.Users

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
    if Users.admin?(conn.assigns[:current_user]) do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: ~p"/")
      |> halt()
    end
  end
end
