defmodule EuropaWeb.GameController do
  use EuropaWeb, :controller

  alias Europa.Games
  alias Europa.Games.Game

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    with games when is_list(games) <- Games.get_recent_for_user(conn.assigns.current_user) do
      render(conn, :index, games: games)
    end
  end

  @spec create(Plug.Conn.t(), map()) :: {:error, Ecto.Changeset.t()} | Plug.Conn.t()
  def create(conn, _params) do
    with {:ok, game} <- Games.create(conn.assigns.current_user) do
      redirect(conn, to: ~p"/games/#{game.uuid}")
    end
  end

  @spec game_over(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def game_over(conn, %{"uuid" => uuid}) do
    current_user = conn.assigns.current_user

    case Games.get_by_uuid(uuid) do
      {:ok, %Game{state: :finished, user_id: ^current_user} = game} ->
        render(conn, :game_over, game: game)

      _ ->
        redirect(conn, to: ~p"/games")
    end
  end

  @spec leaderboard(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def leaderboard(conn, params) do
    {category, leaders} = Games.get_leaders(params)
    render(conn, :leaderboard, category: category, leaders: leaders)
  end
end
