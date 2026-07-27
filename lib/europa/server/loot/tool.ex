defmodule Europa.Server.Loot.Tool do
  use TypedStruct

  alias Europa.Server.Loot
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object

  @type using_type() :: {:put_object, Objects.name()} | nil

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

  typedstruct do
    field :id, atom(), enforce: true
    field :uuid, Loot.uuid(), enforce: true
    field :name, String.t(), enforce: true
    field :description, String.t(), enforce: true
    field :count, pos_integer(), enforce: true
    field :properties, Properties.t(), enforce: true
    field :stackable?, boolean(), enforce: true
    field :using_type, using_type()
    field :use_cost, pos_integer() | nil
    field :weight, Loot.Item.weight(), enforce: true
    field :sound_name, String.t(), enforce: true
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    use_cost = Map.get(attrs, :use_cost)

    %__MODULE__{
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      uuid: Ecto.UUID.generate(),
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      count: Map.fetch!(attrs, :count),
      properties: Map.fetch!(attrs, :properties) |> Properties.new(),
      stackable?: Map.fetch!(attrs, :stackable),
      use_cost: use_cost,
      using_type: Map.get(attrs, :using_type) |> parse_and_validate_using_type(use_cost),
      weight: Map.fetch!(attrs, :weight),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end

  defp parse_and_validate_using_type(%{put_object: object_name}, use_cost) do
    if is_integer(use_cost) and use_cost > 0 do
      object_name = String.to_atom(object_name)
      %Object{} = Objects.object(object_name)
      {:put_object, object_name}
    else
      raise "use_cost is requred for usable tools"
    end
  end

  defp parse_and_validate_using_type(nil, _), do: nil
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Tool do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers
  alias Europa.Server.Player

  @spec id(Tool.t()) :: atom()
  def id(%Tool{id: id}), do: id

  @spec item_type(Tool.t()) :: :tool
  def item_type(%Tool{}), do: :tool

  @spec negative_attrs(Tool.t()) :: list(atom())
  def negative_attrs(%Tool{}) do
    []
  end

  @spec composed_name(Tool.t()) :: String.t()
  def composed_name(%Tool{} = tool) do
    no_significant_properties? = significant_properties(tool.properties) |> Enum.empty?()
    use_cost = "UC:#{tool.use_cost}"

    use_cost =
      cond do
        not usable?(tool) -> ""
        no_significant_properties? -> use_cost
        true -> ", #{use_cost}"
      end

    properties =
      if no_significant_properties? && not usable?(tool) do
        " "
      else
        [
          " (",
          properties_for_composed_name(tool.properties),
          use_cost,
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

  @spec readable_attrs(Tool.t(), Player.t()) :: list()
  def readable_attrs(%Tool{} = tool, _player) do
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

    use_cost =
      if usable?(tool) do
        [{:use_cost, gettext("Use cost"), tool.use_cost}]
      else
        []
      end

    properties_attrs ++
      use_cost ++
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

  @spec usable?(Tool.t()) :: boolean()
  def usable?(%Tool{using_type: nil}), do: false
  def usable?(%Tool{}), do: true

  @spec stackable?(Tool.t()) :: boolean()
  def stackable?(%Tool{stackable?: stackable?}), do: stackable?

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
