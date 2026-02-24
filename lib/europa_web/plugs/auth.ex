defmodule EuropaWeb.Auth do
  import Plug.Conn

  alias Europa.Users

  @behaviour Plug

  # coveralls-ignore-start
  @impl true
  def init(opts) do
    opts
  end

  # coveralls-ignore-stop

  @impl true
  def call(conn, _opts \\ []) do
    case get_session(conn, :current_user) do
      nil ->
        conn

      current_user ->
        do_auth_user(conn, current_user)
    end
  end

  defp do_auth_user(conn, current_user) do
    case Users.get_by_id(current_user) do
      {:ok, user} ->
        assign(conn, :current_user, user.id)

      _ ->
        conn
    end
  end
end
