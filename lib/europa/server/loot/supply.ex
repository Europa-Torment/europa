defmodule Europa.Server.Loot.Supply do
  use TypedStruct

  alias Europa.Server.Loot
  alias Europa.Tools.Types

  @allowed_types [:medicine]

  @type supply_type() :: unquote(Types.one_of(@allowed_types))

  defmodule Properties do
    typedstruct do
      field :health, integer()
    end

    @spec new(map()) :: t()
    def new(attrs) when is_map(attrs) do
      %__MODULE__{
        health: Map.get(attrs, :health)
      }
    end
  end

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :type, supply_type()
    field :name, String.t()
    field :count, pos_integer()
    field :consume_cost, pos_integer()
    field :properties, Properties.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      type: Map.fetch!(attrs, :type) |> String.to_atom(),
      name: Map.fetch!(attrs, :name),
      count: Map.fetch!(attrs, :count),
      consume_cost: Map.fetch!(attrs, :consume_cost),
      properties: Map.fetch!(attrs, :properties) |> Properties.new()
    }
  end

  @spec decrease_count(t(), n :: pos_integer()) :: t()
  def decrease_count(%__MODULE__{} = supply, n \\ 1) when n > 0 do
    updated_value = (supply.count - n) |> max(0)
    struct(supply, count: updated_value)
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Supply do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot.Supply
  alias Europa.Server.Errors

  @spec item_type(Supply.t()) :: :supply
  def item_type(%Supply{}), do: :supply

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
      |> Enum.map(fn {property, value} ->
        name =
          case property do
            :health -> gettext("Health")
          end

        {name, value}
      end)

    properties_attrs ++ [{gettext("Count"), supply.count}, {gettext("Consume cost"), supply.consume_cost}]
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
      end
    end)
  end

  defp significant_properties(%Supply.Properties{} = properties) do
    properties
    |> Map.from_struct()
    |> Enum.filter(fn {_k, value} -> value != nil end)
  end
end
