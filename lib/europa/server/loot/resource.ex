defmodule Europa.Server.Loot.Resource do
  use TypedStruct

  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :id, atom()
    field :uuid, Loot.uuid()
    field :subtype, Loot.item_subtype()
    field :name, String.t()
    field :description, String.t()
    field :count, pos_integer()
    field :weight, Loot.Item.weight()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      uuid: Ecto.UUID.generate(),
      subtype: Map.fetch!(attrs, :subtype) |> String.to_atom(),
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      count: Map.fetch!(attrs, :count),
      weight: Map.fetch!(attrs, :weight)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Resource do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Resource
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers
  alias Europa.Server.Player

  @spec id(Resource.t()) :: atom()
  def id(%Resource{id: id}), do: id

  @spec item_type(Resource.t()) :: :resource
  def item_type(%Resource{}), do: :resource

  @spec item_subtype(Resource.t()) :: Loot.item_subtype()
  def item_subtype(%Resource{subtype: subtype}), do: subtype

  @spec negative_attrs(Resource.t()) :: list(atom())
  def negative_attrs(%Resource{}) do
    []
  end

  @spec composed_name(Resource.t()) :: String.t()
  def composed_name(%Resource{} = resource) do
    "#{resource.name} (#{resource.count})"
  end

  @spec description(Resource.t()) :: String.t()
  def description(%Resource{description: description}), do: description

  @spec readable_attrs(Resource.t(), Player.t()) :: list()
  def readable_attrs(%Resource{} = resource, _player) do
    [
      {:name, gettext("Name"), resource.name},
      {:count, gettext("Count"), resource.count},
      {:weight, gettext("Weight"), NumberHelpers.round(resource.count * resource.weight, 2)}
    ]
  end

  @spec equip(Resource.t()) :: {:error, Errors.NotApplicableError.t()}
  def equip(%Resource{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec unequip(Resource.t()) :: {:error, Errors.NotApplicableError.t()}
  def unequip(%Resource{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec equipable?(Resource.t()) :: false
  def equipable?(%Resource{}), do: false

  @spec consumable?(Resource.t()) :: false
  def consumable?(%Resource{}), do: false

  @spec usable?(Resource.t()) :: boolean()
  def usable?(%Resource{}), do: false

  @spec stackable?(Resource.t()) :: boolean()
  def stackable?(%Resource{}), do: true

  @spec weight(Resource.t()) :: Loot.Item.weight()
  def weight(%Resource{weight: weight, count: count}) do
    weight * count
  end

  @spec player_stats_changes(Resource.t()) :: map()
  def player_stats_changes(%Resource{}) do
    %{}
  end
end
