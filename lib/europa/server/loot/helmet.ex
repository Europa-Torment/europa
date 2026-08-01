defmodule Europa.Server.Loot.Helmet do
  use TypedStruct

  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :id, atom()
    field :uuid, Loot.uuid()
    field :subtype, Loot.item_subtype()
    field :equipped, boolean(), default: false
    field :name, String.t()
    field :description, String.t()
    field :accuracy, pos_integer()
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
      accuracy: Map.fetch!(attrs, :accuracy),
      max_health: Map.fetch!(attrs, :max_health),
      max_warm: Map.fetch!(attrs, :max_warm),
      weight: Map.fetch!(attrs, :weight),
      image_name: Map.fetch!(attrs, :image_name)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Helmet do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Helmet
  alias Europa.Server.Player

  @spec id(Helmet.t()) :: atom()
  def id(%Helmet{id: id}), do: id

  @spec item_type(Helmet.t()) :: :helmet
  def item_type(%Helmet{}), do: :helmet

  @spec item_subtype(Helmet.t()) :: Loot.item_subtype()
  def item_subtype(%Helmet{subtype: subtype}), do: subtype

  @spec negative_attrs(Helmet.t()) :: list(atom())
  def negative_attrs(%Helmet{}) do
    [:weight]
  end

  @spec composed_name(Helmet.t()) :: String.t()
  def composed_name(%Helmet{} = helmet) do
    [
      helmet.name,
      " (",
      "A:#{helmet.accuracy}",
      " H:#{helmet.max_health}",
      " W:#{helmet.max_warm}",
      ")"
    ]
    |> to_string()
  end

  @spec description(Helmet.t()) :: String.t()
  def description(%Helmet{description: description}), do: description

  @spec readable_attrs(Helmet.t(), Player.t()) :: list()
  def readable_attrs(%Helmet{} = helmet, _player) do
    [
      {:name, gettext("Name"), helmet.name},
      {:accuracy, gettext("Accuracy"), helmet.accuracy},
      {:health, gettext("Health"), helmet.max_health},
      {:warm, gettext("Warm"), helmet.max_warm},
      {:weight, gettext("Weight"), helmet.weight}
    ]
  end

  @spec equip(Helmet.t()) :: {:ok, Helmet.t()}
  def equip(%Helmet{} = helmet) do
    {:ok, struct!(helmet, equipped: true)}
  end

  @spec unequip(Helmet.t()) :: {:ok, Helmet.t()}
  def unequip(%Helmet{} = helmet) do
    {:ok, struct!(helmet, equipped: false)}
  end

  @spec equipable?(Helmet.t()) :: true
  def equipable?(%Helmet{}), do: true

  @spec consumable?(Helmet.t()) :: false
  def consumable?(%Helmet{}), do: false

  @spec usable?(Helmet.t()) :: false
  def usable?(%Helmet{}), do: false

  @spec stackable?(Helmet.t()) :: false
  def stackable?(%Helmet{}), do: false

  @spec weight(Helmet.t()) :: Loot.Item.weight()
  def weight(%Helmet{weight: weight}) do
    weight
  end

  @spec player_stats_changes(Helmet.t()) :: map()
  def player_stats_changes(%Helmet{} = helmet) do
    %{
      accuracy: helmet.accuracy,
      max_health: helmet.max_health,
      max_warm: helmet.max_warm
    }
  end
end
