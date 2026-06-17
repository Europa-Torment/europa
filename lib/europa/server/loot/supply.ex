defmodule Europa.Server.Loot.Supply do
  use TypedStruct

  alias Europa.Server
  alias Europa.Server.Loot

  defmodule Properties do
    typedstruct do
      field :health, integer() | nil
      field :warm, integer() | nil
      field :hunger, integer() | nil
      field :thirst, integer() | nil
      field :radiation, integer() | nil
    end

    @spec new(map()) :: t()
    def new(attrs) when is_map(attrs) do
      %__MODULE__{
        health: Map.get(attrs, :health),
        warm: Map.get(attrs, :warm),
        hunger: Map.get(attrs, :hunger),
        thirst: Map.get(attrs, :thirst),
        radiation: Map.get(attrs, :radiation)
      }
    end
  end

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :name, String.t()
    field :count, pos_integer()
    field :consume_cost, Server.move_cost()
    field :properties, Properties.t()
    field :weight, Loot.Item.weight()
    field :sound_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      name: Map.fetch!(attrs, :name),
      count: Map.fetch!(attrs, :count),
      consume_cost: Map.fetch!(attrs, :consume_cost),
      properties: Map.fetch!(attrs, :properties) |> Properties.new(),
      weight: Map.fetch!(attrs, :weight),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end

  @spec decrease_count(t(), n :: pos_integer()) :: t()
  def decrease_count(%__MODULE__{} = supply, n \\ 1) when n > 0 do
    updated_value = (supply.count - n) |> max(0)
    struct!(supply, count: updated_value)
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Supply do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers

  @spec item_type(Supply.t()) :: :supply
  def item_type(%Supply{}), do: :supply

  @spec negative_attrs(Supply.t()) :: list(atom())
  def negative_attrs(%Supply{}) do
    [:consume_cost]
  end

  @spec composed_name(Supply.t()) :: String.t()
  def composed_name(%Supply{} = supply) do
    [
      supply.name,
      " (",
      properties_for_composed_name(supply.properties),
      " CC:#{supply.consume_cost}",
      ") ",
      "(#{supply.count})"
    ]
    |> to_string()
  end

  @spec readable_attrs(Supply.t()) :: list()
  def readable_attrs(%Supply{} = supply) do
    properties_attrs =
      supply.properties
      |> significant_properties()
      |> Enum.sort()
      |> Enum.map(fn {property, value} ->
        name =
          case property do
            :health -> gettext("Health")
            :warm -> gettext("Warm")
            :hunger -> gettext("Hunger")
            :thirst -> gettext("Thirst")
            :radiation -> gettext("Radiation")
          end

        {property, name, value}
      end)

    properties_attrs ++
      [
        {:count, gettext("Count"), supply.count},
        {:consume_cost, gettext("Consume cost"), supply.consume_cost},
        {:weight, gettext("Weight"), NumberHelpers.round(supply.count * supply.weight, 2)}
      ]
  end

  @spec equip(Supply.t()) :: {:error, Errors.NotApplicableError.t()}
  def equip(%Supply{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec unequip(Supply.t()) :: {:error, Errors.NotApplicableError.t()}
  def unequip(%Supply{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec equipable?(Supply.t()) :: false
  def equipable?(%Supply{}), do: false

  @spec consumable?(Supply.t()) :: true
  def consumable?(%Supply{}), do: true

  @spec stackable?(Supply.t()) :: true
  def stackable?(%Supply{}), do: true

  @spec disassemblable?(Supply.t()) :: false
  def disassemblable?(%Supply{}), do: false

  @spec disassemble(Supply.t()) :: {:error, Errors.NotApplicableError.t()}
  def disassemble(%Supply{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec weight(Supply.t()) :: Loot.Item.weight()
  def weight(%Supply{weight: weight, count: count}) do
    weight * count
  end

  @spec player_stats_changes(Supply.t()) :: map()
  def player_stats_changes(%Supply{properties: pripertis}) do
    pripertis
    |> significant_properties()
    |> Enum.into(%{})
  end

  defp properties_for_composed_name(%Supply.Properties{} = properties) do
    properties
    |> significant_properties()
    |> Enum.map_join(", ", fn {property, value} ->
      case property do
        :health -> "H:#{value}"
        :warm -> "W:#{value}"
        :hunger -> "HG:#{value}"
        :thirst -> "TH:#{value}"
        :radiation -> "RD:#{value}"
      end
    end)
  end

  defp significant_properties(%Supply.Properties{} = properties) do
    properties
    |> Map.from_struct()
    |> Enum.filter(fn {_k, value} -> value != nil end)
  end
end
