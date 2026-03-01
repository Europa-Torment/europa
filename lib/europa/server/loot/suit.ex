defmodule Europa.Server.Loot.Suit do
  use TypedStruct

  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :equiped, boolean(), default: false
    field :name, String.t()
    field :efficiency, pos_integer()
    field :max_health, pos_integer()
    field :max_warm, pos_integer()
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
      max_warm: Map.fetch!(attrs, :max_warm),
      image_name: Map.fetch!(attrs, :image_name)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Suit do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot.Suit

  @spec item_type(Suit.t()) :: :suit
  def item_type(%Suit{}), do: :suit

  @spec negative_attrs(Suit.t()) :: list(atom())
  def negative_attrs(%Suit{}) do
    []
  end

  @spec composed_name(Suit.t()) :: String.t()
  def composed_name(%Suit{} = suit) do
    [
      suit.name,
      " (",
      "E:#{suit.efficiency}",
      " H:#{suit.max_health}",
      " W:#{suit.max_warm}",
      ")"
    ]
    |> to_string()
  end

  @spec readable_attrs(Suit.t()) :: list()
  def readable_attrs(%Suit{} = suit) do
    [
      {:name, gettext("Name"), suit.name},
      {:efficiency, gettext("Efficiency"), suit.efficiency},
      {:health, gettext("Health"), suit.max_health},
      {:warm, gettext("Warm"), suit.max_warm}
    ]
  end

  @spec equip(Suit.t()) :: {:ok, Suit.t()}
  def equip(%Suit{} = suit) do
    {:ok, struct(suit, equiped: true)}
  end

  @spec unequip(Suit.t()) :: {:ok, Suit.t()}
  def unequip(%Suit{} = suit) do
    {:ok, struct(suit, equiped: false)}
  end

  @spec equipable?(Suit.t()) :: true
  def equipable?(%Suit{}), do: true

  @spec consumable?(Suit.t()) :: false
  def consumable?(%Suit{}), do: false

  @spec player_stats_changes(Suit.t()) :: map()
  def player_stats_changes(%Suit{} = suit) do
    %{
      efficiency: suit.efficiency,
      max_health: suit.max_health,
      max_warm: suit.max_warm
    }
  end
end
