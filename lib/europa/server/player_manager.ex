defmodule Europa.Server.PlayerManager do
  # coveralls-ignore-start
  @moduledoc """
  Player manager interface.
  """

  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Loot
  alias Europa.Server.Errors

  import Europa.Tools.Conf

  @doc """
  Creates new player.
  """
  @callback new() :: Player.t()

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
  Adds item to player's inventory or returns error when inventory is full.
  """
  @callback add_item(Player.t(), Loot.Item.item()) :: {:ok, Player.t()} | {:error, :full_inventory}

  @doc """
  Equips given item or returns error if item is not exists or not equipable.
  """
  @callback equip_item(Player.t(), Loot.uuid()) ::
              {:ok, Player.t()} | {:error, :not_found} | {:error, Errors.NotApplicable.t()}

  @doc """
  Unequips given item or returns error if item is not exists or not equipable.
  """
  @callback unequip_item(Player.t(), Loot.uuid()) ::
              {:ok, Player.t()} | {:error, :not_found} | {:error, Errors.NotApplicable.t()}

  @doc """
  Replaces item with given updated item.
  """
  @callback update_item(Player.t(), Loot.Item.item()) :: Player.t()

  @doc """
  Deletes item from inventory.
  """
  @callback delete_item(Player.t(), Loot.Item.item()) :: Player.t()

  @doc """
  Finds current equiped weapon or returns error if no weapon is equiped.
  """
  @callback get_equiped_weapon(Player.t()) :: {:ok, Loot.Item.item()} | {:error, :no_weapon}

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
  Reloads current weapon or returns one of errors:

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
  Decreases player's health on given `damage`.
  """
  @callback take_damage(Player.t(), damage :: pos_integer()) :: Player.t()

  ### Implementation callers ###

  def new, do: manager_impl().new()

  def change_view_direction(player, view_direction), do: manager_impl().change_view_direction(player, view_direction)

  def stand_on(player, tile), do: manager_impl().stand_on(player, tile)

  def add_item(player, item), do: manager_impl().add_item(player, item)

  def equip_item(player, item_uuid), do: manager_impl().equip_item(player, item_uuid)

  def unequip_item(player, item_uuid), do: manager_impl().unequip_item(player, item_uuid)

  def update_item(player, item), do: manager_impl().update_item(player, item)

  def delete_item(player, item), do: manager_impl().delete_item(player, item)

  def get_equiped_weapon(player), do: manager_impl().get_equiped_weapon(player)

  def get_equiped_helmet(player), do: manager_impl().get_equiped_helmet(player)

  def get_equiped_suit(player), do: manager_impl().get_equiped_suit(player)

  def get_equiped_boots(player), do: manager_impl().get_equiped_boots(player)

  def find_weapon_ammo(player, weapon), do: manager_impl().find_weapon_ammo(player, weapon)

  def take_damage(player, damage), do: manager_impl().take_damage(player, damage)

  def reload_weapon(player), do: manager_impl().reload_weapon(player)

  ### PRIVATE ###

  defp manager_impl do
    fetch_config!([__MODULE__]) |> Keyword.get(:implementation, Player)
  end

  # coveralls-ignore-stop
end
