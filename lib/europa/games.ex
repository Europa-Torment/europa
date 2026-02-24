defmodule Europa.Games do
  alias Europa.Repo
  alias Europa.Games.Game
  alias Europa.Users
  alias Europa.Server
  alias Europa.Server.Sup, as: ServerSup

  import Ecto.Query

  @spec get_recent_for_user(Users.id()) :: list(Game.t())
  def get_recent_for_user(user_id) when is_integer(user_id) do
    from(g in Game, where: g.user_id == ^user_id, order_by: [desc: g.id], limit: 30)
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

  @spec create(Users.id()) :: {:ok, Game.t()} | {:error, Ecto.Changeset.t()}
  def create(user_id) when is_integer(user_id) do
    user_id
    |> build_create_params()
    |> Game.create_changeset()
    |> Repo.insert()
    |> start_server()
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
