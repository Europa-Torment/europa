defmodule Europa.Server.Loot.Tool do
  use TypedStruct

  alias Europa.Tools.Types
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon
  alias Europa.Tools.AttrsDeterminator

  @allowed_tool_types [:weapon_parts, :key, :matches]

  @type tool_type() :: unquote(Types.one_of(@allowed_tool_types))

  defmodule Properties do
    typedstruct do
      field :level, pos_integer() | nil
    end

    @spec new(map()) :: t()
    def new(attrs) when is_map(attrs) do
      %__MODULE__{
        level: Map.get(attrs, :level)
      }
    end
  end

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :name, String.t()
    field :description, String.t()
    field :type, tool_type()
    field :count, pos_integer()
    field :properties, Properties.t()
    field :stackable?, boolean()
    field :weight, Loot.Item.weight()
    field :sound_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      type: Map.fetch!(attrs, :type) |> to_atom() |> validate_type!(),
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      count: Map.fetch!(attrs, :count),
      properties: Map.fetch!(attrs, :properties) |> Properties.new(),
      stackable?: Map.fetch!(attrs, :stackable),
      weight: Map.fetch!(attrs, :weight),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end

  @spec decrease_count(t(), n :: pos_integer()) :: t()
  def decrease_count(%__MODULE__{} = tool, n \\ 1) when n > 0 do
    updated_value = (tool.count - n) |> max(0)
    struct!(tool, count: updated_value)
  end

  @spec from_weapon(Weapon.t()) :: list(t())
  def from_weapon(%Weapon{} = weapon) do
    weapon_parts =
      Loot.get_items(:tool)
      |> Enum.find(fn {tool, _} -> tool.type == "weapon_parts" && tool.properties.level == weapon.level end)
      |> elem(0)
      |> AttrsDeterminator.determine_attrs()
      |> Map.put(:count, weapon.parts_count - 1)
      |> new()

    [weapon_parts]
  end

  @spec generate_key() :: t()
  def generate_key do
    Loot.get_items(:tool)
    |> Enum.filter(fn {tool, _} -> tool.type == "key" end)
    |> WeightedRandom.take_one()
    |> AttrsDeterminator.determine_attrs()
    |> Map.put(:count, 1)
    |> new()
  end

  @spec generate_matches() :: t()
  def generate_matches do
    Loot.get_items(:tool)
    |> Enum.filter(fn {tool, _} -> tool.type == "matches" end)
    |> WeightedRandom.take_one()
    |> AttrsDeterminator.determine_attrs()
    |> Map.put(:count, 1)
    |> new()
  end

  defp validate_type!(type) when type in @allowed_tool_types, do: type

  defp validate_type!(type) do
    raise "invalid tool type: #{inspect(type)}"
  end

  defp to_atom(value) when is_atom(value), do: value

  defp to_atom(value) when is_binary(value) do
    String.to_atom(value)
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Tool do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers

  @spec item_type(Tool.t()) :: :tool
  def item_type(%Tool{}), do: :tool

  @spec negative_attrs(Tool.t()) :: list(atom())
  def negative_attrs(%Tool{}) do
    []
  end

  @spec composed_name(Tool.t()) :: String.t()
  def composed_name(%Tool{} = tool) do
    properties =
      if significant_properties(tool.properties) |> Enum.empty?() do
        " "
      else
        [
          " (",
          properties_for_composed_name(tool.properties),
          ") "
        ]
        |> Enum.join("")
      end

    [
      tool.name,
      properties,
      "(#{tool.count})"
    ]
    |> to_string()
  end

  @spec description(Tool.t()) :: String.t()
  def description(%Tool{description: description}), do: description

  @spec readable_attrs(Tool.t()) :: list()
  def readable_attrs(%Tool{} = tool) do
    properties_attrs =
      tool.properties
      |> significant_properties()
      |> Enum.sort()
      |> Enum.map(fn {property, value} ->
        name =
          case property do
            :level -> gettext("Level")
          end

        {property, name, value}
      end)

    properties_attrs ++
      [
        {:count, gettext("Count"), tool.count},
        {:weight, gettext("Weight"), NumberHelpers.round(tool.count * tool.weight, 2)}
      ]
  end

  @spec equip(Tool.t()) :: {:error, Errors.NotApplicableError.t()}
  def equip(%Tool{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec unequip(Tool.t()) :: {:error, Errors.NotApplicableError.t()}
  def unequip(%Tool{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec equipable?(Tool.t()) :: false
  def equipable?(%Tool{}), do: false

  @spec consumable?(Tool.t()) :: false
  def consumable?(%Tool{}), do: false

  @spec stackable?(Tool.t()) :: boolean()
  def stackable?(%Tool{stackable?: stackable?}), do: stackable?

  @spec disassemblable?(Tool.t()) :: false
  def disassemblable?(%Tool{}), do: false

  @spec disassemble(Tool.t()) :: {:error, Errors.NotApplicableError.t()}
  def disassemble(%Tool{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec weight(Tool.t()) :: Loot.Item.weight()
  def weight(%Tool{weight: weight, count: count}) do
    weight * count
  end

  @spec player_stats_changes(Tool.t()) :: map()
  def player_stats_changes(%Tool{}) do
    %{}
  end

  defp properties_for_composed_name(%Tool.Properties{} = properties) do
    properties
    |> significant_properties()
    |> Enum.map_join(", ", fn {property, value} ->
      case property do
        :level -> "LVL:#{value}"
      end
    end)
  end

  defp significant_properties(%Tool.Properties{} = properties) do
    properties
    |> Map.from_struct()
    |> Enum.filter(fn {_k, value} -> value != nil end)
  end
end
