defmodule Europa.Server.PlanetManager do
  # coveralls-ignore-start

  @moduledoc """
  Planet manager interface.
  """

  alias Europa.Server.Errors.NotApplicableError
  alias Europa.Server
  alias Europa.Server.Planet
  alias Europa.Server.Loot
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Action
  alias Europa.Server.Errors
  alias Europa.Server.Event

  import Europa.Tools.Conf

  @doc """
  Generates new Planet.
  """
  @callback new(keyword()) :: Planet.t()

  @doc """
  Returns tile player initially stand on.
  """
  @callback player_initial_stand_on_tile(Planet.t()) :: Planet.tile()

  @doc """
  Returns atom representation of `player` tile
  """
  @callback player() :: atom()

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
  Size of visible land depencs on `view_distance` config param and current datetime (server one, not real).
  """
  @callback get_visible_land(Planet.t(), DateTime.t()) :: Planet.land()

  @doc """
  Returns visible part of planet's map.
  """
  @callback get_map(Planet.t()) :: Planet.land()

  @doc """
  Move player in given direction or attack enemy with melee weapon.
  If move succeded response is:
  ```
  {:moved, updated_planet, move_cost, tile}
  ```

  where `move_cost` - quantity of game moves which were required to perform the move and `tile` is tile player stepped on.

  If move not allowed response is:
  ```
  {:stay, tile, [{enemy, damage}], move_cost}
  ```

  where `tile` is tile player can't step on.

  If player attacked enemy with melee weapon response is:
  ```
  {:attack, updated_planet, [{enemy, damage}], move_cost}
  ```

  where `[{enemy, damage}]` - list of damaged enemies.
  """
  @callback move(Planet.t(), Planet.direction(), Player.t()) ::
              {:moved, Planet.t(), Server.move_cost(), Planet.tile(), next_to_interactive_tile :: boolean()}
              | {:stay, Planet.tile()}
              | {:attack, Planet.t(), list({Enemy.t(), damage :: pos_integer()}), Server.move_cost()}

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
              {:error, :no_item | :nothing} | {:ok, Planet.t(), Player.t(), Loot.ItemBox.t()}

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
              {:ok, {Planet.t(), Player.t(), list({Enemy.t() | Npc.t(), damage :: pos_integer()}), Server.move_cost()}}
              | {:error, :empty_magazine}
              | {:error, :no_weapon}
              | {:error, :miss, Player.t(), Server.move_cost()}

  @callback unload_item_box_weapon(Planet.t(), Player.t(), Loot.uuid()) ::
              {:ok, Planet.t(), Player.t(), Loot.ItemBox.t(), Loot.Item.item()}
              | {:error, :empty_magazine}
              | {:error, :no_item}
              | {:error, :nothing}
              | {:error, Errors.NotApplicableError.t()}

  @callback interact(Planet.t(), Planet.direction(), opts :: keyword()) ::
              {:ok, Planet.t(), Planet.interaction()}
              | {:error, :nothing}

  @doc """
  Uses given tool or returns NotApplicable error.
  """
  @callback use_tool(Planet.t(), Loot.Item.item(), Planet.direction()) ::
              {:ok, Planet.t()} | {:error, NotApplicableError.t()}

  @doc """
  Runs planet activities such as enemies moving and attacking. Takes current `planet` and `moves_count`.
  Returns updated planet and list of performed actions.

  Should be called after each player's action with moves cost.
  """
  @callback tick(Planet.t(), Server.move_cost()) :: {:ok, Planet.t(), list(Action.t())}

  @doc """
  Removes last event from every struct that has :events field with list of Event.t() in visible part of planet.
  """
  @callback remove_last_events(Planet.t()) :: {:ok, Planet.t(), list({event_owner_uuid :: Ecto.UUID.t(), Event.t()})}

  @doc """
  Сrops land to size of visible land.
  """
  @callback crop_land(Planet.t()) :: {:ok, Planet.t()}

  ### Implementation callers ###

  def new(options), do: manager_impl().new(options)
  def player_initial_stand_on_tile(planet), do: manager_impl().player_initial_stand_on_tile(planet)
  def player, do: manager_impl().player()
  def blood_tile(tile), do: manager_impl().blood_tile(tile)
  def view_distance, do: manager_impl().view_distance()
  def allowed_directions, do: manager_impl().allowed_directions()
  def readable_tile_name(tile), do: manager_impl().readable_tile_name(tile)
  def get_visible_land(planet, current_datetime), do: manager_impl().get_visible_land(planet, current_datetime)
  def get_map(planet), do: manager_impl().get_map(planet)
  def land_size(planet), do: manager_impl().land_size(planet)
  def move(planet, direction, player), do: manager_impl().move(planet, direction, player)
  def loot(planet, direction), do: manager_impl().loot(planet, direction)
  def take_loot(planet, player, item_uuid), do: manager_impl().take_loot(planet, player, item_uuid)
  def use_tool(planet, tool, view_direction), do: manager_impl().use_tool(planet, tool, view_direction)

  def drop_item(planet, player, item_uuid), do: manager_impl().drop_item(planet, player, item_uuid)
  def tick(planet, moves_count), do: manager_impl().tick(planet, moves_count)
  def remove_last_events(planet), do: manager_impl().remove_last_events(planet)
  def shoot(planet, player), do: manager_impl().shoot(planet, player)

  def unload_item_box_weapon(planet, player, item_uuid),
    do: manager_impl().unload_item_box_weapon(planet, player, item_uuid)

  def crop_land(planet), do: manager_impl().crop_land(planet)

  def interact(planet, direction, opts), do: manager_impl().interact(planet, direction, opts)

  ### PRIVATE ###

  defp manager_impl do
    fetch_config!([__MODULE__]) |> Keyword.get(:implementation, Planet)
  end

  # coveralls-ignore-stop
end
