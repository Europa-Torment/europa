defmodule Europa.Server.Enemy do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Event
  alias Europa.Server.Enemy.Utils.FilesReader
  alias Europa.Tools.AttrsDeterminator
  alias Europa.Tools.Types

  import Europa.Tools.Randomizer

  @enemies_attrs FilesReader.parse_file()

  @allowed_enemy_types [:monster]

  @type attrs :: map()
  @type enemy_type :: unquote(Types.one_of(@allowed_enemy_types))

  for {{enemy, _}, i} <- Enum.with_index(@enemies_attrs) do
    fun_name = String.to_atom("__extract_strings_for_#{i}")

    def unquote(fun_name)() do
      gettext(unquote(enemy.name))
      gettext(unquote(enemy.description))

      unquote_splicing(
        for phrase <- enemy.phrases do
          quote do
            gettext(unquote(phrase))
          end
        end
      )
    end
  end

  typedstruct do
    field :uuid, Ecto.UUID.t(), enforce: true
    field :type, enemy_type(), enforce: true
    field :name, String.t(), enforce: true
    field :description, String.t(), enforce: true
    field :health, non_neg_integer(), enforce: true
    field :max_health, pos_integer(), enforce: true
    field :damage, pos_integer(), enforce: true
    field :move_distance, pos_integer(), enforce: true
    field :accuracy, pos_integer(), enforce: true
    field :radioactive?, boolean(), enforce: true
    field :cold?, boolean(), enforce: true
    field :healer?, boolean(), enforce: true
    field :heal_possibility, non_neg_integer(), enforce: true
    field :heal_unit, non_neg_integer(), enforce: true
    field :stand_on, Planet.tile()
    field :image_name, String.t(), enforce: true
    field :events, list(Event.t()), default: []
    field :phrases, list(String.t()), default: []
    field :max_items, pos_integer(), enforce: true
  end

  @spec new(attrs()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      type: Map.fetch!(attrs, :type) |> String.to_atom(),
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      max_health: Map.fetch!(attrs, :max_health),
      health: Map.fetch!(attrs, :health),
      damage: Map.fetch!(attrs, :damage),
      move_distance: Map.fetch!(attrs, :move_distance),
      accuracy: Map.fetch!(attrs, :accuracy),
      radioactive?: Map.get(attrs, :radioactive, false),
      cold?: Map.get(attrs, :cold, false),
      healer?: Map.get(attrs, :healer, false),
      heal_possibility: Map.get(attrs, :heal_possibility, 0),
      heal_unit: Map.get(attrs, :heal_unit, 0),
      phrases: Map.fetch!(attrs, :phrases),
      max_items: Map.fetch!(attrs, :max_items),
      image_name: Map.fetch!(attrs, :image_name),
      stand_on: nil
    }
  end

  @spec readable_stats(t()) :: list({String.t(), String.t() | integer()})
  def readable_stats(%__MODULE__{move_distance: move_distance} = enemy) do
    damage =
      if move_distance > 1 do
        "#{enemy.damage}x#{move_distance}"
      else
        "#{enemy.damage}"
      end

    [
      {gettext("Name"), enemy.name},
      {gettext("Health"), enemy.health},
      {gettext("Accuracy"), enemy.accuracy},
      {gettext("Damage"), damage},
      {gettext("Move distance"), move_distance}
    ]
  end

  @spec generate_enemy() :: t()
  def generate_enemy do
    @enemies_attrs
    |> WeightedRandom.take_one()
    |> AttrsDeterminator.determine_attrs()
    |> new()
  end

  @spec take_damage(t(), damage :: pos_integer()) :: t()
  def take_damage(%__MODULE__{} = enemy, damage) when is_integer(damage) and damage > 0 do
    updated_health = max(0, enemy.health - damage)

    enemy
    |> struct!(health: updated_health)
    |> add_events([Event.new({:damaged, damage})])
  end

  @spec heal(t(), health :: pos_integer()) :: t()
  def heal(%__MODULE__{} = enemy, health) when is_integer(health) and health > 0 do
    updated_health = min(enemy.max_health, enemy.health + health)

    enemy
    |> struct!(health: updated_health)
    |> add_events([Event.new({:healed, health})])
  end

  @spec healer?(t()) :: boolean()
  def healer?(%__MODULE__{} = enemy) do
    enemy.healer? && enemy.heal_possibility > 0 && enemy.heal_unit > 0
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
  def maybe_add_speech_event(%__MODULE__{phrases: [_ | _] = phrases, events: []} = enemy) do
    if m_to_n?(1, 5) do
      phrase = Enum.random(phrases)
      event = Event.new({:speech, phrase})
      add_events(enemy, [event])
    else
      enemy
    end
  end

  def maybe_add_speech_event(%__MODULE__{} = enemy), do: enemy
end
