defmodule Europa.Games.Game do
  use Ecto.Schema

  alias Europa.Users.User
  alias Europa.Tools.Types

  import Ecto.Changeset

  @required_create_params [:user_id, :uuid, :state]
  @required_finish_params [:state, :finish_reason]

  @states [:active, :finished]

  @finish_reasons [:died, :server_error]

  @type finish_reason() :: unquote(Types.one_of(@finish_reasons))

  schema "games" do
    belongs_to :user, User

    field :uuid, :string
    field :state, Ecto.Enum, values: @states
    field :finish_reason, Ecto.Enum, values: @finish_reasons

    timestamps()
  end

  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, @required_create_params)
    |> validate_required(@required_create_params)
  end

  @spec finish_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def finish_changeset(%__MODULE__{} = game, params \\ %{}) do
    params = Map.put(params, :state, "finished")

    game
    |> cast(params, @required_finish_params)
    |> validate_required(@required_finish_params)
  end
end
