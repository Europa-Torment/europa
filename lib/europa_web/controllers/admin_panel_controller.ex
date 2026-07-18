defmodule EuropaWeb.AdminPanelController do
  use EuropaWeb, :controller

  alias Europa.Games
  alias Europa.Users

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    stats = %{
      active_games_count: Games.get_active_games_count(),
      last_day_games_count: Games.get_last_day_games_count(),
      total_games_count: Games.get_total_games_count(),
      total_users_count: Users.get_users_count(),
      new_users_count: Users.get_new_users_count()
    }

    render(conn, :index, stats: stats)
  end
end
