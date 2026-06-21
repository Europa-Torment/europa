defmodule Europa.Server.PlayerManager do
  # coveralls-ignore-start
  @moduledoc """
  Player manager interface.
  """

  alias Europa.Server
  alias Europa.Server.Action
  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Loot
  alias Europa.Server.Characters.Character
  alias Europa.Server.Errors

  import Europa.Tools.Conf

  @doc """
  Creates new player.
  """
  @callback new(Character.t()) :: Player.t()

  @doc """
  Returns list of readable player stats in format:
  ```
  [{"Stat name", "stat value"}]
  ```
  """
  @callback readable_stats(Player.t()) :: list({String.t(), String.t() | integer()})

  @doc """
  Changes player view direction.
  """
  @callback change_view_direction(Player.t(), Planet.direction()) :: Player.t()

  @doc """
  Changes player stand_on tile.
  """
  @callback stand_on(Player.t(), Planet.tile()) :: Player.t()

  @doc """
  Adds item to player's inventory.
  """
  @callback add_item(Player.t(), Loot.Item.item()) :: {:ok, Player.t()}

  @doc """
  Returns item from inventory.
  """
  @callback get_item(Player.t(), Loot.uuid()) :: {:ok, Loot.Item.item()} | {:error, :not_found}

  @doc """
  Drops item from inventory.
  """
  @callback drop_item(Player.t(), Loot.uuid(), count :: pos_integer() | nil) ::
              {:ok, Player.t(), Loot.Item.item()} | {:error, :not_found}

  @doc """
  Equips given item or returns error if item is not exists or not equipable.
  """
  @callback equip_item(Player.t(), Loot.uuid()) ::
              {:ok, Player.t()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}

  @doc """
  Disassembles given item.
  """
  @callback disassemble_item(Player.t(), Loot.uuid()) ::
              {:ok, Player.t(), Loot.Item.item()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}

  @doc """
  Unequips given item or returns error if item is not exists or not equipable.
  """
  @callback unequip_item(Player.t(), Loot.uuid()) ::
              {:ok, Player.t()} | {:error, :not_found} | {:error, Errors.NotApplicableError.t()}

  @doc """
  Replaces item with given updated item.
  """
  @callback update_item(Player.t(), Loot.Item.item()) :: Player.t()

  @doc """
  Deletes item from inventory.
  """
  @callback delete_item(Player.t(), Loot.Item.item()) :: Player.t()

  @doc """
  Crafts item from it's blueprint.
  """
  @callback craft_item(Player.t(), Loot.Blueprint.t()) :: {:ok, Player.t()} | {:error, Errors.NotApplicableError.t()}

  @doc """
  Returns amount of given item.
  """
  @callback tools_amount(Player.t(), Loot.Tool.t()) :: non_neg_integer()

  @doc """
  Checks if player has enough tools of given types
  """
  @callback enough_tools?(Player.t(), list(Loot.Item.item())) :: boolean()

  @doc """
  Finds current equiped weapon or returns error if no weapon is equiped.
  """
  @callback get_equiped_weapon(Player.t()) :: {:ok, Loot.Item.item()} | {:error, :no_weapon}

  @doc """
  Finds current equiped melee weapon or returns error if no melee weapon is equiped.
  """
  @callback get_equiped_melee_weapon(Player.t()) :: {:ok, Loot.Item.item()} | {:error, :no_melee_weapon}

  @doc """
  Finds current equiped helmet or returns error if no helmet is equiped.
  """
  @callback get_equiped_helmet(Player.t()) :: {:ok, Loot.Item.item()} | {:error, :no_helmet}

  @doc """
  Finds current equiped suit or returns error if no suit is equiped.
  """
  @callback get_equiped_suit(Player.t()) :: {:ok, Loot.Item.item()} | {:error, :no_suit}

  @doc """
  Finds current equiped boots or returns error if no boots is equiped.
  """
  @callback get_equiped_boots(Player.t()) :: {:ok, Loot.Item.item()} | {:error, :no_boots}

  @doc """
  Finds ammo for given weapon or returns error if no such ammo in inventory.
  """
  @callback find_weapon_ammo(Player.t(), weapon :: Loot.Item.item()) ::
              {:ok, ammo :: Loot.Item.item()} | {:error, :no_ammo}

  @doc """
  Reloads given weapon or returns one of errors:

  `{:error, :no_weapon}` - no equiped weapon
  `{:error, :no_ammo}` - no necessary ammo in inventory
  `{:error, :full_magazine}` - weapon is already fully loaded
  `{:error, %Europa.Server.Errors.NotApplicableError{}}` - invalid item is equiped as weapon
  """
  @callback reload_weapon(Player.t()) ::
              {:ok, Player.t(), weapon :: Loot.Item.item()}
              | {:error, :no_weapon}
              | {:error, :no_ammo}
              | {:error, :full_magazine}
              | {:error, Errors.NotApplicableError.t()}

  @doc """
  Reloads given weapon or returns one of errors:

  `{:error, :not_found}` - weapon with given uuid is not found
  `{:error, :no_ammo}` - no necessary ammo in inventory
  `{:error, :full_magazine}` - weapon is already fully loaded
  `{:error, %Europa.Server.Errors.NotApplicableError{}}` - invalid item is equiped as weapon
  """
  @callback reload_weapon(Player.t(), Loot.uuid()) ::
              {:ok, Player.t(), weapon :: Loot.Item.item()}
              | {:error, :not_found}
              | {:error, :no_ammo}
              | {:error, :full_magazine}
              | {:error, Errors.NotApplicableError.t()}

  @callback unload_weapon(Player.t(), Loot.uuid()) ::
              {:ok, Player.t(), weapon :: Loot.Item.item()}
              | {:error, :not_found}
              | {:error, :empty_magazine}

  @doc """
  Decreases player's health on given `damage`.
  """
  @callback take_damage(Player.t(), damage :: pos_integer()) :: Player.t()

  @doc """
  Increases player's radiation on given `radiation`.
  """
  @callback increase_radiation(Player.t(), radiation_units :: pos_integer()) :: Player.t()

  @callback consume_supply(Player.t(), Loot.uuid()) ::
              {:ok, Player.t(), item :: Loot.Item.item()}
              | {:error, :not_found}
              | {:error, Errors.NotApplicableError.t()}

  @callback get_inventory(Player.t(), Loot.item_type() | :all) :: Player.inventory()

  @callback inventory_weight(Player.t()) :: number()

  @doc """
  Returns inventory_weight/max_weight ratio.
  """
  @callback weight_ratio(Player.t()) :: number()

  @doc """
  Increases player's `warm`.
  """
  @callback warm_up(Player.t(), warm_units :: pos_integer()) :: Player.t()

  @doc """
  Increases player's `thirst`.
  """
  @callback increase_thirst(Player.t(), thirst_units :: integer()) :: Player.t()

  @callback tick(Player.t(), Server.move_cost()) :: {:ok, Player.t(), list(Action.t())}

  ### Implementation callers ###

  def new(character), do: manager_impl().new(character)

  def change_view_direction(player, view_direction), do: manager_impl().change_view_direction(player, view_direction)

  def stand_on(player, tile), do: manager_impl().stand_on(player, tile)

  def add_item(player, item), do: manager_impl().add_item(player, item)

  def get_item(player, item_uuid), do: manager_impl().get_item(player, item_uuid)

  def drop_item(player, item_uuid, count), do: manager_impl().drop_item(player, item_uuid, count)

  def disassemble_item(player, item_uuid), do: manager_impl().disassemble_item(player, item_uuid)

  def equip_item(player, item_uuid), do: manager_impl().equip_item(player, item_uuid)

  def unequip_item(player, item_uuid), do: manager_impl().unequip_item(player, item_uuid)

  def update_item(player, item), do: manager_impl().update_item(player, item)

  def delete_item(player, item), do: manager_impl().delete_item(player, item)

  def tools_amount(player, tool), do: manager_impl().tools_amount(player, tool)

  def enough_tools?(player, tools), do: manager_impl().enough_tools?(player, tools)

  def craft_item(player, blueprint), do: manager_impl().craft_item(player, blueprint)

  def get_equiped_weapon(player), do: manager_impl().get_equiped_weapon(player)

  def get_equiped_melee_weapon(player), do: manager_impl().get_equiped_melee_weapon(player)

  def get_equiped_helmet(player), do: manager_impl().get_equiped_helmet(player)

  def get_equiped_suit(player), do: manager_impl().get_equiped_suit(player)

  def get_equiped_boots(player), do: manager_impl().get_equiped_boots(player)

  def find_weapon_ammo(player, weapon), do: manager_impl().find_weapon_ammo(player, weapon)

  def take_damage(player, damage), do: manager_impl().take_damage(player, damage)

  def reload_weapon(player), do: manager_impl().reload_weapon(player)

  def reload_weapon(player, weapon_uuid), do: manager_impl().reload_weapon(player, weapon_uuid)

  def unload_weapon(player, weapon_uuid), do: manager_impl().unload_weapon(player, weapon_uuid)

  def consume_supply(player, supply_uuid), do: manager_impl().consume_supply(player, supply_uuid)

  def get_inventory(player, items_type), do: manager_impl().get_inventory(player, items_type)

  def inventory_weight(player), do: manager_impl().inventory_weight(player)

  def weight_ratio(player), do: manager_impl().weight_ratio(player)

  def warm_up(player, warm_units), do: manager_impl().warm_up(player, warm_units)

  def increase_thirst(player, thirst_units), do: manager_impl().increase_thirst(player, thirst_units)

  def increase_radiation(player, radiation_units), do: manager_impl().increase_radiation(player, radiation_units)

  def tick(player, moves_count), do: manager_impl().tick(player, moves_count)

  ### PRIVATE ###

  defp manager_impl do
    fetch_config!([__MODULE__]) |> Keyword.get(:implementation, Player)
  end

  # coveralls-ignore-stop
end
