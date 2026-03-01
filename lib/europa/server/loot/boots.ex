defmodule Europa.Server.Loot.Boots do
  use TypedStruct

  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :equiped, boolean(), default: false
    field :name, String.t()
    field :efficiency, pos_integer()
    field :max_health, pos_integer()
    field :image_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      equiped: false,
      name: Map.fetch!(attrs, :name),
      efficiency: Map.fetch!(attrs, :efficiency),
      max_health: Map.fetch!(attrs, :max_health),
      image_name: Map.fetch!(attrs, :image_name)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Boots do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot.Boots

  @spec item_type(Boots.t()) :: :boots
  def item_type(%Boots{}), do: :boots

  @spec negative_attrs(Boots.t()) :: list(atom())
  def negative_attrs(%Boots{}) do
    []
  end

  @spec composed_name(Boots.t()) :: String.t()
  def composed_name(%Boots{} = boots) do
    [
      boots.name,
      " (",
      "E:#{boots.efficiency}",
      " H:#{boots.max_health}",
      ")"
    ]
    |> to_string()
  end

  @spec readable_attrs(Boots.t()) :: list()
  def readable_attrs(%Boots{} = boots) do
    [
      {:name, gettext("Name"), boots.name},
      {:efficiency, gettext("Efficiency"), boots.efficiency},
      {:health, gettext("Health"), boots.max_health}
    ]
  end

  @spec equip(Boots.t()) :: {:ok, Boots.t()}
  def equip(%Boots{} = boots) do
    {:ok, struct(boots, equiped: true)}
  end

  @spec unequip(Boots.t()) :: {:ok, Boots.t()}
  def unequip(%Boots{} = boots) do
    {:ok, struct(boots, equiped: false)}
  end

  @spec equipable?(Boots.t()) :: true
  def equipable?(%Boots{}), do: true

  @spec consumable?(Boots.t()) :: false
  def consumable?(%Boots{}), do: false

  @spec player_stats_changes(Boots.t()) :: map()
  def player_stats_changes(%Boots{} = boots) do
    %{
      efficiency: boots.efficiency,
      max_health: boots.max_health
    }
  end
end
