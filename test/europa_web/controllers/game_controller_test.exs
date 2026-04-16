defmodule EuropaWeb.GameControllerTest do
  use EuropaWeb.ConnCase

  alias Europa.Games
  alias Europa.Server
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.PlanetManagerMock
  alias Europa.Server.PlayerManagerMock

  setup :verify_on_exit!

  setup do
    user = insert(:user)
    conn = auth_conn(user)

    {:ok, conn: conn, user: user}
  end

  describe "GET /games" do
    setup do
      path = ~p"/games"
      {:ok, path: path}
    end

    test "renders index template", %{conn: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "index.html"
    end

    test "redirect if unauthorized", %{conn_without_auth: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_unauthorized()
    end
  end

  describe "GET /games/new" do
    setup do
      path = ~p"/games/new"
      {:ok, path: path}
    end

    test "redirects to game page", %{conn: conn, path: path, user: user} do
      tile = Tiles.tile(:snow).atom_value

      PlayerManagerMock
      |> allow_server_mock(user.id)
      |> expect(:new, fn -> build(:player) end)
      |> expect(:stand_on, fn player, ^tile -> player end)

      PlanetManagerMock
      |> allow_server_mock(user.id)
      |> expect(:new, fn _year -> build(:planet) end)
      |> expect(:player_initial_stand_on_tile, fn _planet -> tile end)

      conn = get(conn, path)
      game = Games.get_recent_for_user(user.id) |> List.first()
      assert redirected_to(conn) == ~p"/games/#{game.uuid}"

      stop_server(game)
    end

    test "redirects if unauthorized", %{conn_without_auth: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_unauthorized()
    end
  end

  describe "GET /games/:uuid/game-over" do
    setup ctx do
      game = insert(:game, state: :finished, user: ctx.user)
      path = ~p"/games/#{game.uuid}/game-over"

      {:ok, game: game, path: path}
    end

    test "renders game_over template", %{conn: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "game_over.html"
    end

    test "redirects to /games page when game not finished", %{conn: conn, user: user} do
      game = insert(:game, state: :active, user: user)
      path = ~p"/games/#{game.uuid}/game-over"
      conn = get(conn, path)

      assert redirected_to(conn) == ~p"/games"
    end

    test "redirects to /games page when game not belongs to user", %{conn: conn} do
      game = insert(:game, state: :finished)
      path = ~p"/games/#{game.uuid}/game-over"
      conn = get(conn, path)

      assert redirected_to(conn) == ~p"/games"
    end

    test "redirects if unauthorized", %{conn_without_auth: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_unauthorized()
    end
  end

  describe "GET /games/leaderboard" do
    setup do
      path = ~p"/games/leaderboard"
      {:ok, path: path}
    end

    test "renders leaderboard template (with default catgory)", %{conn: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "leaderboard.html"
    end

    test "renders leaderboard template (with category)", %{conn: conn, path: path} do
      for [{category, _}] <- Games.leader_categories() do
        conn = get(conn, path, category: "#{category}")
        assert render_template(conn) == "leaderboard.html"
      end
    end

    test "redirect if unauthorized", %{conn_without_auth: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_unauthorized()
    end
  end

  defp stop_server(game) do
    server_pid = game.uuid |> Server.server_name() |> Process.whereis()
    GenServer.stop(server_pid, :normal)
  end

  defp allow_server_mock(mock_module, user_id) do
    mock_module
    |> allow(self(), fn ->
      case Games.get_recent_for_user(user_id) do
        [] ->
          self()

        [game] ->
          game.uuid
          |> Server.server_name()
          |> Process.whereis()
      end
    end)
  end
end
