defmodule Europa.Server.Enemy do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Event
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Enemy.Utils.FilesReader
  alias Europa.Tools.AttrsDeterminator
  alias Europa.Tools.Types

  import Europa.Tools.Randomizer

  @enemies_attrs FilesReader.parse_file()

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
    field :events, list(Event.t()), default: []
    field :phrases, list(String.t()), default: []
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
      phrases: Map.fetch!(attrs, :phrases),
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
    @enemies_attrs
    |> WeightedRandom.take_one()
    |> AttrsDeterminator.determine_attrs()
    |> new()
  end

  @spec take_damage(t(), damage :: pos_integer) :: t()
  def take_damage(%__MODULE__{} = enemy, damage) when is_integer(damage) and damage > 0 do
    updated_health = max(0, enemy.health - damage)

    enemy
    |> struct!(health: updated_health)
    |> add_events([Event.new({:damaged, damage})])
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = enemy, tile) do
    struct!(enemy, stand_on: tile)
  end

  @spec add_events(t(), list(Event.t())) :: t()
  def add_events(enemy, []), do: enemy

  def add_events(%__MODULE__{} = enemy, events) when is_list(events) do
    events = Event.stack_events(enemy.events ++ events)
    struct!(enemy, events: events)
  end

  @spec maybe_add_speech_event(t()) :: t()
  def maybe_add_speech_event(%__MODULE__{phrases: []} = enemy), do: enemy

  def maybe_add_speech_event(%__MODULE__{phrases: phrases} = enemy) do
    if m_to_n?(1, 5) && dont_have_speech_event?(enemy) do
      phrase = Enum.random(phrases)
      event = Event.new({:speech, phrase})
      add_events(enemy, [event])
    else
      enemy
    end
  end

  defp dont_have_speech_event?(%__MODULE__{events: []}), do: true

  defp dont_have_speech_event?(%__MODULE__{events: events}) do
    not Enum.any?(events, fn
      %Event{type: {:speech, _}} -> true
      _ -> false
    end)
  end
end
