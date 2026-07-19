defmodule Europa.Server.Npc do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Characters.Character
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Event

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @max_accuracy fetch_config!([:weapons, :max_accuracy])

  @health_from fetch_config!([:game_params, :npc, :health, :from])
  @health_to fetch_config!([:game_params, :npc, :health, :to])

  @type target() :: :player | Ecto.UUID.t() | nil

  typedstruct do
    field :uuid, Ecto.UUID.t(), enforce: true
    field :character, Character.t(), enforce: true
    field :story, Character.story(), enforce: true
    field :stand_on, Planet.tile(), enforce: true
    field :health, non_neg_integer(), enforce: true
    field :accuracy, pos_integer(), enforce: true
    field :view_direction, Planet.direction(), enforce: true
    field :weapon, Weapon.t(), enforce: true
    field :target, target()
    field :events, list(Event.t()), default: []
  end

  @spec new(Character.t(), Planet.tile()) :: t()
  def new(%Character{} = character, stand_on) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      character: character,
      story: Character.random_story(character),
      stand_on: stand_on,
      health: health(),
      accuracy: accuracy(),
      view_direction: Planet.allowed_directions() |> Enum.random(),
      weapon: Loot.generate_item(:weapon)
    }
  end

  @spec readable_stats(t()) :: list({String.t(), String.t() | integer()})
  def readable_stats(%__MODULE__{character: character} = npc) do
    [
      {gettext("Name"), character.name},
      {gettext("Age"), character.current_age},
      {gettext("Gender"), Character.readable_gender(character)},
      {gettext("Health"), npc.health},
      {gettext("Aggressive"), aggressive(npc)}
    ]
  end

  @spec take_damage(t(), damage :: pos_integer()) :: t()
  def take_damage(%__MODULE__{} = npc, damage) when is_integer(damage) and damage > 0 do
    updated_health = max(0, npc.health - damage)

    npc
    |> struct!(health: updated_health)
    |> add_events([Event.new({:damaged, damage})])
  end

  @spec add_events(t(), list(Event.t())) :: t()
  def add_events(npc, []), do: npc

  def add_events(%__MODULE__{} = npc, events) when is_list(events) do
    events =
      Enum.uniq_by(npc.events ++ events, fn event ->
        case event.type do
          type when is_atom(type) -> type
          _ -> event.uuid
        end
      end)
      |> Event.stack_events()

    struct!(npc, events: events)
  end

  @spec maybe_add_speech_event(t()) :: t()
  def maybe_add_speech_event(%__MODULE__{character: %Character{short_phrases: [_ | _] = phrases}, events: []} = npc) do
    if m_to_n?(1, 5) do
      phrase = Enum.random(phrases)
      event = Event.new({:speech, phrase})
      add_events(npc, [event])
    else
      npc
    end
  end

  def maybe_add_speech_event(%__MODULE__{} = npc), do: npc

  @spec trigger(t(), target()) :: t()
  def trigger(%__MODULE__{} = npc, target) do
    struct!(npc, target: target)
  end

  @spec change_view_direction(t(), Planet.direction()) :: t()
  def change_view_direction(%__MODULE__{} = npc, new_direction) do
    if new_direction in Planet.allowed_directions() do
      struct!(npc, view_direction: new_direction)
    else
      npc
    end
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = npc, tile) do
    struct!(npc, stand_on: tile)
  end

  defp aggressive(%__MODULE__{target: :player}), do: gettext("Yes")
  defp aggressive(_), do: gettext("No")

  defp accuracy do
    from = div(@max_accuracy, 2)
    to = @max_accuracy

    Enum.random(from..to)
  end

  defp health do
    Enum.random(@health_from..@health_to)
  end
end
