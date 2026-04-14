defmodule Europa.Games.Game do
  use Ecto.Schema

  alias Europa.Users.User
  alias Europa.Tools.Types

  import Ecto.Changeset

  @required_create_params [:user_id, :uuid, :state]
  @required_finish_params [:state, :finish_reason]
  @required_update_stats_params [:moves_count, :great_red_spots, :killed_enemies, :days]

  @states [:active, :finished]

  @finish_reasons [:died, :server_error]

  @type finish_reason() :: unquote(Types.one_of(@finish_reasons))

  schema "games" do
    belongs_to :user, User

    field :uuid, :string
    field :state, Ecto.Enum, values: @states
    field :finish_reason, Ecto.Enum, values: @finish_reasons
    field :moves_count, :integer, default: 0
    field :great_red_spots, :integer, default: 0
    field :killed_enemies, :integer, default: 0
    field :days, :integer, default: 0

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

  @spec update_stats_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_stats_changeset(%__MODULE__{} = game, params \\ %{}) do
    game
    |> cast(params, @required_update_stats_params)
    |> validate_required(@required_update_stats_params)
    |> validate_number(:moves_count, greater_than_or_equal_to: 0)
    |> validate_number(:great_red_spots, greater_than_or_equal_to: 0)
    |> validate_number(:killed_enemies, greater_than_or_equal_to: 0)
    |> validate_number(:days, greater_than_or_equal_to: 0)
  end
end
