defmodule Europa.Server.Loot.Blueprints.Blueprint do
  use TypedStruct

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon

  @type resources :: list(Loot.Resource.t())

  typedstruct enforce: true do
    field :item, Loot.Item.item()
    field :resources, resources()
  end

  @spec new(Loot.Item.item(), resources()) :: t()
  def new(item, resources) when is_list(resources) do
    %__MODULE__{
      item: item,
      resources: resources
    }
  end

  @spec from_map(map()) :: t()
  def from_map(%{item_type: item_type, item_id: item_id, resources: resources}) do
    item_type = String.to_atom(item_type)
    item_id = String.to_atom(item_id)
    item = Loot.generate_item_by_id(item_type, item_id, 1) |> maybe_unload_weapon()

    resources =
      Enum.map(resources, fn %{id: id, count: count} ->
        id = String.to_atom(id)
        Loot.generate_item_by_id(:resource, id, count)
      end)

    new(item, resources)
  end

  defp maybe_unload_weapon(%Weapon{rounds_loaded: rounds_loaded} = weapon) when rounds_loaded > 0 do
    {:ok, {updated_weapon, _}} = Weapon.unload(weapon)
    updated_weapon
  end

  defp maybe_unload_weapon(item), do: item
end
