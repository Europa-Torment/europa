defmodule Europa.Server.Loot.Tool do
  use TypedStruct

  alias Europa.Server.NotApplicableError
  alias Europa.Server.Loot
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Errors.NotApplicableError

  @type using_type() :: {:put_object, Objects.name()} | :switch | nil

  defmodule Properties do
    typedstruct do
      field :level, pos_integer()
      field :durability, non_neg_integer()
      field :illumination_range, pos_integer()
    end

    @spec new(map()) :: t()
    def new(attrs) when is_map(attrs) do
      %__MODULE__{
        level: Map.get(attrs, :level),
        durability: Map.get(attrs, :durability),
        illumination_range: Map.get(attrs, :illumination_range)
      }
    end
  end

  typedstruct do
    field :id, atom(), enforce: true
    field :uuid, Loot.uuid(), enforce: true
    field :subtype, Loot.item_subtype(), enforce: true
    field :name, String.t(), enforce: true
    field :description, String.t(), enforce: true
    field :count, pos_integer(), enforce: true
    field :properties, Properties.t(), enforce: true
    field :stackable?, boolean(), enforce: true
    field :active?, boolean()
    field :using_type, using_type()
    field :use_cost, pos_integer() | nil
    field :weight, Loot.Item.weight(), enforce: true
    field :sound_name, String.t(), enforce: true
  end

  @spec new(map()) :: t() | no_return()
  def new(attrs) when is_map(attrs) do
    use_cost = Map.get(attrs, :use_cost)
    using_type = Map.get(attrs, :using_type) |> parse_using_type()

    active? =
      if using_type == :switch do
        false
      else
        nil
      end

    tool =
      %__MODULE__{
        id: Map.fetch!(attrs, :id) |> String.to_atom(),
        uuid: Ecto.UUID.generate(),
        subtype: Map.fetch!(attrs, :subtype) |> String.to_atom(),
        name: Map.fetch!(attrs, :name),
        description: Map.fetch!(attrs, :description),
        count: Map.fetch!(attrs, :count),
        properties: Map.fetch!(attrs, :properties) |> Properties.new(),
        stackable?: Map.fetch!(attrs, :stackable),
        active?: active?,
        use_cost: use_cost,
        using_type: using_type,
        weight: Map.fetch!(attrs, :weight),
        sound_name: Map.fetch!(attrs, :sound_name)
      }

    if tool.stackable? && tool.properties.durability do
      raise "tool cannot be stackable and has durability at same time, tool: #{inspect(tool)}"
    end

    if not tool.stackable? && tool.count != 1 do
      raise "count for not stackable tools should be equal to 1"
    end

    if tool.using_type && (is_nil(use_cost) || not is_integer(use_cost)) do
      raise "use_cost is required for usable tools"
    end

    tool
  end

  @spec switch(t()) :: {:ok, t()} | {:error, NotApplicableError.t()}
  def switch(%__MODULE__{using_type: :switch} = tool) do
    {:ok, struct!(tool, active?: !tool.active?)}
  end

  def switch(_) do
    {:error, %NotApplicableError{}}
  end

  @spec with_durability?(t()) :: boolean()
  def with_durability?(%__MODULE__{properties: %Properties{durability: durability}}) when not is_nil(durability) do
    true
  end

  def with_durability?(_), do: false

  @spec decrease_durability(t()) :: {:ok, t()} | {:error, NotApplicableError.t()}
  def decrease_durability(%__MODULE__{properties: %Properties{durability: durability} = properties} = tool)
      when is_integer(durability) and durability > 0 do
    updated_properties = struct!(properties, durability: durability - 1)
    {:ok, struct!(tool, properties: updated_properties)}
  end

  def decrease_durability(_), do: {:error, %NotApplicableError{}}

  defp parse_using_type(%{put_object: object_name}) do
    object_name = String.to_atom(object_name)
    %Object{} = Objects.object(object_name)
    {:put_object, object_name}
  end

  defp parse_using_type("switch") do
    :switch
  end

  defp parse_using_type(nil), do: nil
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Tool do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors.NotApplicableError
  alias Europa.Tools.NumberHelpers
  alias Europa.Server.Player

  @displayable_properties [:level, :durability, :illumination_range]

  @spec id(Tool.t()) :: atom()
  def id(%Tool{id: id}), do: id

  @spec item_type(Tool.t()) :: :tool
  def item_type(%Tool{}), do: :tool

  @spec item_subtype(Tool.t()) :: Loot.item_subtype()
  def item_subtype(%Tool{subtype: subtype}), do: subtype

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

    count =
      if tool.stackable? do
        "(#{tool.count})"
      else
        ""
      end

    [
      tool.name,
      properties,
      count
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
            :durability -> gettext("Durability")
            :illumination_range -> gettext("Illumination range")
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

  @spec equip(Tool.t()) :: {:error, NotApplicableError.t()}
  def equip(%Tool{}) do
    {:error, %NotApplicableError{}}
  end

  @spec unequip(Tool.t()) :: {:error, NotApplicableError.t()}
  def unequip(%Tool{}) do
    {:error, %NotApplicableError{}}
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
        :durability -> "D:#{value}"
        :illumination_range -> "IR:#{value}"
      end
    end)
  end

  defp significant_properties(%Tool.Properties{} = properties) do
    properties
    |> Map.from_struct()
    |> Enum.filter(fn {k, value} -> k in @displayable_properties && value != nil end)
  end
end
