defmodule Europa.GamesTest do
  use Europa.DataCase

  alias Europa.Games
  alias Europa.Games.Game
  alias Europa.Server
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.PlanetManagerMock
  alias Europa.Server.PlayerManagerMock

  setup :verify_on_exit!

  setup do
    user = insert(:user)
    {:ok, user: user}
  end

  describe "get_recent_for_user/1" do
    test "returns all user games", %{user: user} do
      insert_list(20, :game)

      expected_games = insert_list(10, :game, user: user)
      games = Games.get_recent_for_user(user.id)

      assert Enum.count(games) == Enum.count(expected_games)

      for %Game{id: id} <- expected_games do
        assert Enum.any?(games, fn game -> game.id == id end)
      end
    end
  end

  describe "get_by_uuid/1" do
    setup do
      game = insert(:game)
      {:ok, game: game}
    end

    test "returns game", %{game: %Game{id: id} = game} do
      assert {:ok, %Game{id: ^id}} = Games.get_by_uuid(game.uuid)
    end

    test "returns error if game not found" do
      assert Games.get_by_uuid("fake") == {:error, :not_found}
    end
  end

  describe "create/1" do
    test "creates game for given user and starts game server", %{user: user} do
      tile = Tiles.tile(:snow).atom_value

      PlayerManagerMock
      |> allow_server_mock(user.id)
      |> expect(:new, fn -> build(:player) end)
      |> expect(:stand_on, fn player, ^tile -> player end)

      PlanetManagerMock
      |> allow_server_mock(user.id)
      |> expect(:new, fn -> build(:planet) end)
      |> expect(:player_initial_stand_on_tile, fn _planet -> tile end)

      assert {:ok, %Game{} = game} = Games.create(user.id)
      assert game.user_id == user.id
      assert game.state == :active

      server_pid = game.uuid |> Server.server_name() |> Process.whereis()
      assert Process.alive?(server_pid)

      GenServer.stop(server_pid, :normal)
    end
  end

  describe "finish_game/2" do
    setup do
      game = insert(:game)
      {:ok, game: game}
    end

    test "finishes game", %{game: game} do
      finish_reason = :died

      assert {:ok, updated_game} = Games.finish_game(game.uuid, finish_reason)
      assert updated_game.state == :finished
      assert updated_game.finish_reason == finish_reason
    end

    test "returns error if game not found" do
      assert Games.finish_game("fake", :died) == {:error, :not_found}
    end
  end

  describe "update_stats/2" do
    setup do
      game = insert(:game)
      {:ok, game: game}
    end

    test "updates game stats", %{game: game} do
      params = %{moves_count: 10, great_red_spots: 2, killed_enemies: 100}

      assert {:ok, updated_game} = Games.update_stats(game.uuid, params)
      assert updated_game.moves_count == params.moves_count
      assert updated_game.great_red_spots == params.great_red_spots
      assert updated_game.killed_enemies == params.killed_enemies
    end

    test "returns error if game not found" do
      params = %{moves_count: 10, great_red_spots: 2, killed_enemies: 10}
      assert Games.update_stats("fake", params) == {:error, :not_found}
    end
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
