defmodule Europa.Server.PlanetManager do
  # coveralls-ignore-start

  @moduledoc """
  Planet manager interface.
  """

  alias Europa.Server
  alias Europa.Server.Planet
  alias Europa.Server.Loot
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Action
  alias Europa.Server.Errors

  import Europa.Tools.Conf

  @doc """
  Generates new Planet.
  """
  @callback new() :: Planet.t()

  @doc """
  Returns tile player initially stand on.
  """
  @callback player_initial_stand_on_tile(Planet.t()) :: Planet.tile()

  @doc """
  Returns atom representation of `snow` tile
  """
  @callback snow() :: atom()

  @doc """
  Returns atom representation of `path` tile
  """
  @callback path() :: atom()

  @doc """
  Returns atom representation of `water` tile
  """
  @callback water() :: atom()

  @doc """
  Returns atom representation of `ice` tile
  """
  @callback ice() :: atom()

  @doc """
  Returns atom representation of `snow_blood` tile
  """
  @callback snow_blood() :: atom()

  @doc """
  Returns atom representation of `path_blood` tile
  """
  @callback path_blood() :: atom()

  @doc """
  Returns atom representation of `ice_blood` tile
  """
  @callback ice_blood() :: atom()

  @doc """
  Returns atom representation of `player` tile
  """
  @callback player() :: atom()

  @doc """
  Returns bloody version of given tile or unchanged tile if there is no bloody version of it.
  """
  @callback blood_tile(Planet.tile()) :: Planet.tile()

  @doc """
  Returns planet view distance
  """
  @callback view_distance() :: pos_integer()

  @doc """
  Returns list of allowed directions (`up`, `down`, `right`, `left`)
  """
  @callback allowed_directions() :: [Planet.direction()]

  @doc """
  Returns land size.
  """
  @callback land_size(Planet.t()) :: pos_integer()

  @doc """
  Returns human-readable tile name.
  """
  @callback readable_tile_name(Planet.tile()) :: Planet.readable_tile_name()

  @doc """
  Reutrns visible part of planet's land.
  Size of visible land depencs on `@view_distance`.
  """
  @callback get_visible_land(Planet.t()) :: Planet.land()

  @doc """
  Move player in given direction.
  If move succeded response is:
  ```
  {:moved, updated_planet, move_cost, tile}
  ```

  where `move_cost` - quantity of game moves which were required to perform the move and `tile` is tile player stepped on.

  If move not allowed response is:
  ```
  {:stay, tile}
  ```

  where `tile` is tile player can't step on.
  """
  @callback move(Planet.t(), Planet.direction(), player_stand_on :: Planet.tile()) ::
              {:moved, Planet.t(), Server.move_cost(), Planet.tile()} | {:stay, Planet.tile()}

  @doc """
  Checks if there is `ItemBox` at next tile by current `view_direction` and returns the `ItemBox` if so.
  """
  @callback loot(Planet.t(), Player.t()) :: {:open_item_box, Loot.ItemBox.t()} | {:error, :nothing}

  @doc """
  Checks if there is `ItemBox` at next tile by current `view_direction` and takes nth item from it if so.
  Success response is:
  ```
  {:ok, updated_planet, updated_player, updated_item_box}
  ```

  Given item will moved from `ItemBox` to player's inventory.
  """
  @callback take_loot(Planet.t(), Player.t(), Loot.uuid()) ::
              {:error, :full_inventory | :no_item | :nothing} | {:ok, Planet.t(), Player.t(), Loot.ItemBox.t()}

  @doc """
  Performs player shoot.

  Success response (player hits some enemies) is:
  ```
  {:ok, updated_planet, updated_player, [{enemy, damage}], move_cost}
  ```

  where `[{enemy, damage}]` - list of damaged enemies.

  Miss response (player hits no enemies) is:
  ```
  {:error, :miss, updated_player, move_cost}
  ```
  """
  @callback shoot(Planet.t(), Player.t()) ::
              {:ok, {Planet.t(), Player.t(), list({Enemy.t(), damage :: pos_integer()}), Server.move_cost()}}
              | {:error, :empty_magazine}
              | {:error, :no_weapon}
              | {:error, :miss, Player.t(), Server.move_cost()}

  @callback unload_item_box_weapon(Planet.t(), Player.t(), Loot.uuid()) ::
              {:ok, Planet.t(), Player.t(), Loot.ItemBox.t(), Loot.Item.item()}
              | {:error, :empty_magazine}
              | {:error, :no_item}
              | {:error, :nothing}
              | {:error, Errors.NotApplicableError.t()}

  @doc """
  Runs planet activities such as enemies moving and attacking. Takes current `planet` and `moves_count`.
  Returns updated planet and list of performed actions.

  Should be called after each player's action with moves cost.
  """
  @callback tick(Planet.t(), Server.move_cost()) :: {:ok, Planet.t(), list(Action.t())}

  @doc """
  Сrops land to size of visible land.
  """
  @callback crop_land(Planet.t()) :: {:ok, Planet.t()}

  ### Implementation callers ###

  def new, do: manager_impl().new()
  def player_initial_stand_on_tile(planet), do: manager_impl().player_initial_stand_on_tile(planet)
  def snow, do: manager_impl().snow()
  def ice, do: manager_impl().ice()
  def water, do: manager_impl().water()
  def path, do: manager_impl().path()

  def snow_blood, do: manager_impl().snow_blood()
  def ice_blood, do: manager_impl().ice_blood()
  def path_blood, do: manager_impl().path_blood()
  def player, do: manager_impl().player()

  def blood_tile(tile), do: manager_impl().blood_tile(tile)

  def view_distance, do: manager_impl().view_distance()
  def allowed_directions, do: manager_impl().allowed_directions()

  def readable_tile_name(tile), do: manager_impl().readable_tile_name(tile)

  def get_visible_land(planet), do: manager_impl().get_visible_land(planet)

  def land_size(planet), do: manager_impl().land_size(planet)

  def move(planet, direction, stand_on_tile), do: manager_impl().move(planet, direction, stand_on_tile)

  def loot(planet, direction), do: manager_impl().loot(planet, direction)

  def take_loot(planet, player, item_uuid), do: manager_impl().take_loot(planet, player, item_uuid)

  def tick(planet, moves_count), do: manager_impl().tick(planet, moves_count)

  def shoot(planet, player), do: manager_impl().shoot(planet, player)

  def unload_item_box_weapon(planet, player, item_uuid),
    do: manager_impl().unload_item_box_weapon(planet, player, item_uuid)

  def crop_land(planet), do: manager_impl().crop_land(planet)

  ### PRIVATE ###

  defp manager_impl do
    fetch_config!([__MODULE__]) |> Keyword.get(:implementation, Planet)
  end

  # coveralls-ignore-stop
end
