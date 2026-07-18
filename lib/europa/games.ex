defmodule Europa.Games do
  use Gettext, backend: Europa.Gettext

  alias Europa.Repo
  alias Europa.Games.Game
  alias Europa.Games.LeadersCache
  alias Europa.Users
  alias Europa.Users.User
  alias Europa.Server
  alias Europa.Server.Sup, as: ServerSup
  alias Europa.Tools.Types

  import Ecto.Query
  import Europa.Tools.Conf

  @allowed_leaders_categories [
    days: gettext("Days survived"),
    great_red_spots: gettext("Great Red Spots survived"),
    kills: gettext("Killed enemies"),
    moves: gettext("Total moves"),
    games_played: gettext("Games played")
  ]

  @default_leaders_category :days

  @leaders_limit fetch_config!([__MODULE__, :leaders_limit])
  @active_games_per_user_limit fetch_config!([__MODULE__, :active_games_per_user_limit])

  @type leaders_category :: unquote(Types.one_of(Map.keys(Enum.into(@allowed_leaders_categories, %{}))))
  @type leaders :: {leaders_category(), list({{username :: String.t(), result :: integer()}, index :: pos_integer()})}

  @spec get_active_for_user(Users.id()) :: list(Game.t())
  def get_active_for_user(user_id) when is_integer(user_id) do
    from(g in Game, where: g.user_id == ^user_id and g.state == :active, order_by: [desc: g.id])
    |> Repo.all()
  end

  @spec get_by_uuid(Ecto.UUID.t()) :: {:ok, Game.t()} | {:error, :not_found}
  def get_by_uuid(uuid) when is_binary(uuid) do
    case Repo.get_by(Game, uuid: uuid) do
      %Game{} = game ->
        {:ok, game}

      _ ->
        {:error, :not_found}
    end
  end

  @spec create(Users.id()) ::
          {:ok, Game.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:active_games_limit_reached, active_games_count :: non_neg_integer()}}
  def create(user_id) when is_integer(user_id) do
    with :ok <- check_active_games_limit(user_id) do
      user_id
      |> build_create_params()
      |> Game.create_changeset()
      |> Repo.insert()
      |> start_server()
    end
  end

  @spec finish_game(Ecto.UUID.t(), Game.finish_reason()) ::
          {:ok, Game.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def finish_game(uuid, reason) do
    with {:ok, game} <- get_by_uuid(uuid) do
      game
      |> Game.finish_changeset(%{finish_reason: reason})
      |> Repo.update()
    end
  end

  @spec finish_active_games() :: :ok
  def finish_active_games do
    Game
    |> where(state: :active)
    |> Repo.all()
    |> Enum.each(fn game -> finish_game(game.uuid, :server_error) end)
  end

  @spec update_stats(Ecto.UUID.t(), params :: map()) ::
          {:ok, Game.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def update_stats(uuid, params) when is_map(params) do
    with {:ok, game} <- get_by_uuid(uuid) do
      game
      |> Game.update_stats_changeset(params)
      |> Repo.update()
    end
  end

  @spec leader_categories() :: list({leaders_category(), readable_category_name :: String.t()})
  def leader_categories do
    @allowed_leaders_categories
  end

  @spec get_leaders(map()) :: leaders()
  def get_leaders(params) do
    category =
      case Map.get(params, "category") do
        "kills" -> :kills
        "days" -> :days
        "great_red_spots" -> :great_red_spots
        "moves" -> :moves
        "games_played" -> :games_played
        _ -> @default_leaders_category
      end

    case LeadersCache.get(category) do
      {:ok, leaders} -> {category, leaders}
      _ -> do_get_leaders(category)
    end
  end

  @spec get_active_games_count() :: non_neg_integer()
  def get_active_games_count do
    from(g in Game, where: g.state == :active, select: count(g.id)) |> Repo.one!()
  end

  @spec get_last_day_games_count() :: non_neg_integer()
  def get_last_day_games_count do
    from(g in Game, where: g.inserted_at >= ago(24, "hour"), select: count(g.id)) |> Repo.one!()
  end

  @spec get_total_games_count() :: non_neg_integer()
  def get_total_games_count do
    from(g in Game, select: count(g.id)) |> Repo.one!()
  end

  defp do_get_leaders(category) do
    leaders =
      category
      |> find_leaders()
      |> Enum.with_index(1)

    {:ok, true} = LeadersCache.put(category, leaders)

    {category, leaders}
  end

  defp find_leaders(:days) do
    from(g in Game,
      join: u in User,
      on: u.id == g.user_id,
      group_by: u.username,
      select: {u.username, sum(g.days)},
      order_by: [desc: sum(g.days)],
      limit: @leaders_limit
    )
    |> Repo.all()
  end

  defp find_leaders(:great_red_spots) do
    from(g in Game,
      join: u in User,
      on: u.id == g.user_id,
      group_by: u.username,
      select: {u.username, sum(g.great_red_spots)},
      order_by: [desc: sum(g.great_red_spots)],
      limit: @leaders_limit
    )
    |> Repo.all()
  end

  defp find_leaders(:kills) do
    from(g in Game,
      join: u in User,
      on: u.id == g.user_id,
      group_by: u.username,
      select: {u.username, sum(g.killed_enemies)},
      order_by: [desc: sum(g.killed_enemies)],
      limit: @leaders_limit
    )
    |> Repo.all()
  end

  defp find_leaders(:moves) do
    from(g in Game,
      join: u in User,
      on: u.id == g.user_id,
      group_by: u.username,
      select: {u.username, sum(g.moves_count)},
      order_by: [desc: sum(g.moves_count)],
      limit: @leaders_limit
    )
    |> Repo.all()
  end

  defp find_leaders(:games_played) do
    from(g in Game,
      join: u in User,
      on: u.id == g.user_id,
      group_by: u.username,
      select: {u.username, count(g.id)},
      order_by: [desc: count(g.id)],
      limit: @leaders_limit
    )
    |> Repo.all()
  end

  defp check_active_games_limit(user_id) when is_integer(user_id) do
    active_games_count =
      from(g in Game, where: g.user_id == ^user_id and g.state == :active, select: count(g.id)) |> Repo.one()

    if active_games_count < @active_games_per_user_limit do
      :ok
    else
      {:error, {:active_games_limit_reached, @active_games_per_user_limit}}
    end
  end

  defp build_create_params(user_id) do
    %{
      user_id: user_id,
      uuid: Ecto.UUID.generate(),
      state: :active
    }
  end

  defp start_server({:ok, game} = response) do
    child_spec = Server.child_spec(game.uuid)
    {:ok, _} = DynamicSupervisor.start_child(ServerSup, child_spec)
    response
  end

  defp start_server(error) do
    error
  end
end
