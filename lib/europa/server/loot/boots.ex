defmodule Europa.Server.Loot.Boots do
  use TypedStruct

  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :id, atom()
    field :uuid, Loot.uuid()
    field :subtype, Loot.item_subtype()
    field :equipped, boolean(), default: false
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
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      uuid: Ecto.UUID.generate(),
      subtype: Map.fetch!(attrs, :subtype) |> String.to_atom(),
      equipped: false,
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
  alias Europa.Server.Player

  @spec id(Boots.t()) :: atom()
  def id(%Boots{id: id}), do: id

  @spec item_type(Boots.t()) :: :boots
  def item_type(%Boots{}), do: :boots

  @spec item_subtype(Boots.t()) :: Loot.item_subtype()
  def item_subtype(%Boots{subtype: subtype}), do: subtype

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

  @spec readable_attrs(Boots.t(), Player.t()) :: list()
  def readable_attrs(%Boots{} = boots, _player) do
    [
      {:name, gettext("Name"), boots.name},
      {:efficiency, Player.readable_stat_name(:efficiency), boots.efficiency},
      {:max_health, Player.readable_stat_name(:max_health), boots.max_health},
      {:max_warm, Player.readable_stat_name(:max_warm), boots.max_warm},
      {:weight, gettext("Weight"), boots.weight}
    ]
  end

  @spec equip(Boots.t()) :: {:ok, Boots.t()}
  def equip(%Boots{} = boots) do
    {:ok, struct!(boots, equipped: true)}
  end

  @spec unequip(Boots.t()) :: {:ok, Boots.t()}
  def unequip(%Boots{} = boots) do
    {:ok, struct!(boots, equipped: false)}
  end

  @spec equipable?(Boots.t()) :: true
  def equipable?(%Boots{}), do: true

  @spec consumable?(Boots.t()) :: false
  def consumable?(%Boots{}), do: false

  @spec usable?(Boots.t()) :: false
  def usable?(%Boots{}), do: false

  @spec stackable?(Boots.t()) :: false
  def stackable?(%Boots{}), do: false

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
