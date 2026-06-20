defmodule Europa.Server.Loot.Boots do
  use TypedStruct

  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :equiped, boolean(), default: false
    field :name, String.t()
    field :description, String.t()
    field :efficiency, pos_integer()
    field :max_health, pos_integer()
    field :max_warm, pos_integer()
    field :weight, Loot.Item.weight()
    field :image_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      equiped: false,
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      efficiency: Map.fetch!(attrs, :efficiency),
      max_health: Map.fetch!(attrs, :max_health),
      max_warm: Map.fetch!(attrs, :max_warm),
      weight: Map.fetch!(attrs, :weight),
      image_name: Map.fetch!(attrs, :image_name)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Boots do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Boots
  alias Europa.Server.Errors

  @spec item_type(Boots.t()) :: :boots
  def item_type(%Boots{}), do: :boots

  @spec negative_attrs(Boots.t()) :: list(atom())
  def negative_attrs(%Boots{}) do
    [:weight]
  end

  @spec composed_name(Boots.t()) :: String.t()
  def composed_name(%Boots{} = boots) do
    [
      boots.name,
      " (",
      "E:#{boots.efficiency}",
      " H:#{boots.max_health}",
      " W:#{boots.max_warm}",
      ")"
    ]
    |> to_string()
  end

  @spec description(Boots.t()) :: String.t()
  def description(%Boots{description: description}), do: description

  @spec readable_attrs(Boots.t()) :: list()
  def readable_attrs(%Boots{} = boots) do
    [
      {:name, gettext("Name"), boots.name},
      {:efficiency, gettext("Efficiency"), boots.efficiency},
      {:health, gettext("Health"), boots.max_health},
      {:warm, gettext("Warm"), boots.max_warm},
      {:weight, gettext("Weight"), boots.weight}
    ]
  end

  @spec equip(Boots.t()) :: {:ok, Boots.t()}
  def equip(%Boots{} = boots) do
    {:ok, struct!(boots, equiped: true)}
  end

  @spec unequip(Boots.t()) :: {:ok, Boots.t()}
  def unequip(%Boots{} = boots) do
    {:ok, struct!(boots, equiped: false)}
  end

  @spec equipable?(Boots.t()) :: true
  def equipable?(%Boots{}), do: true

  @spec consumable?(Boots.t()) :: false
  def consumable?(%Boots{}), do: false

  @spec stackable?(Boots.t()) :: false
  def stackable?(%Boots{}), do: false

  @spec disassemblable?(Boots.t()) :: false
  def disassemblable?(%Boots{}), do: false

  @spec disassemble(Boots.t()) :: {:error, Errors.NotApplicableError.t()}
  def disassemble(%Boots{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec weight(Boot.t()) :: Loot.Item.weight()
  def weight(%Boots{weight: weight}) do
    weight
  end

  @spec player_stats_changes(Boots.t()) :: map()
  def player_stats_changes(%Boots{} = boots) do
    %{
      efficiency: boots.efficiency,
      max_health: boots.max_health,
      max_warm: boots.max_warm
    }
  end
end
