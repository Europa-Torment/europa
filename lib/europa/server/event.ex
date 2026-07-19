defmodule Europa.Server.Event do
  use TypedStruct

  alias Europa.Server.Loot.Weapon

  @type uuid :: Ecto.UUID.t()
  @type health_change :: pos_integer()
  @type radiation_change :: pos_integer()
  @type warm_change :: integer()
  @type death_reason :: atom()

  @type event_type ::
          {:damaged, health_change()}
          | {:healed, health_change()}
          | {:radiation, radiation_change()}
          | {:warm_up, warm_change()}
          | {:speech, text :: String.t()}
          | {:dead, death_reason()}
          | {:shoot, Weapon.t()}
          | :enemy_killed
          | :interested
          | :great_red_spot
          | :missed_shoot

  typedstruct enforce: true do
    field :uuid, uuid()
    field :type, event_type()
  end

  @spec new(event_type()) :: t()
  def new(type) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      type: type
    }
  end

  @spec stack_events(list(t())) :: list(t())
  def stack_events(events) when is_list(events) do
    {stackable, not_stackable} =
      Enum.split_with(events, fn %__MODULE__{type: type} -> stackable?(type) end)

    stacked =
      stackable
      |> Enum.group_by(fn %__MODULE__{type: {name, _}} -> name end)
      |> Enum.map(fn {name, list} ->
        sum = Enum.reduce(list, 0, fn %__MODULE__{type: {_, val}}, acc -> acc + val end)
        new({name, sum})
      end)

    not_stackable ++ stacked
  end

  defp stackable?({name, value}) when is_atom(name) and is_number(value) do
    true
  end

  defp stackable?(_), do: false
end
