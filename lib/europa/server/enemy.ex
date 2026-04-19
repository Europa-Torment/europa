defmodule Europa.Server.Enemy do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Tools.AttrsDeterminator
  alias Europa.Tools.FilesCache
  alias Europa.Tools.Types

  @templates_path "/enemies/"
  @filename "enemies.json"

  @allowed_enemy_types [:monster]

  @type attrs :: map()
  @type enemy_type :: unquote(Types.one_of(@allowed_enemy_types))

  typedstruct enforce: true do
    field :type, enemy_type()
    field :name, String.t()
    field :health, non_neg_integer()
    field :damage, pos_integer()
    field :move_distance, pos_integer()
    field :accuracy, pos_integer()
    field :radioactive?, boolean()
    field :stand_on, Planet.tile()
    field :image_name, String.t()
  end

  @spec new(attrs()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      type: Map.fetch!(attrs, :type) |> String.to_atom(),
      name: Map.fetch!(attrs, :name),
      health: Map.fetch!(attrs, :health),
      damage: Map.fetch!(attrs, :damage),
      move_distance: Map.fetch!(attrs, :move_distance),
      accuracy: Map.fetch!(attrs, :accuracy),
      radioactive?: Map.get(attrs, :radioactive, false),
      image_name: Map.fetch!(attrs, :image_name),
      stand_on: Tiles.tile(:snow).atom_value
    }
  end

  @spec readable_stats(t()) :: list({String.t(), String.t() | integer()})
  def readable_stats(%__MODULE__{} = enemy) do
    [
      {gettext("Name"), enemy.name},
      {gettext("Health"), enemy.health},
      {gettext("Accuracy"), enemy.accuracy},
      {gettext("Damage"), enemy.damage},
      {gettext("Move distance"), enemy.move_distance}
    ]
  end

  @spec generate_enemy() :: t()
  def generate_enemy do
    parse_file()
    |> WeightedRandom.take_one()
    |> AttrsDeterminator.determine_attrs()
    |> new()
  end

  @spec take_damage(t(), damage :: pos_integer) :: t()
  def take_damage(%__MODULE__{} = enemy, damage) when is_integer(damage) and damage > 0 do
    updated_health = max(0, enemy.health - damage)
    struct!(enemy, health: updated_health)
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = enemy, tile) do
    struct!(enemy, stand_on: tile)
  end

  defp parse_file do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, @filename])

    case FilesCache.get(path) do
      {:ok, cached_file} ->
        cached_file

      _ ->
        path
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
        |> Enum.map(fn attrs -> {attrs, attrs.random_weight} end)
        |> tap(fn file_content -> FilesCache.put(path, file_content) end)
    end
  end
end
