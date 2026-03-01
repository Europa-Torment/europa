defmodule Europa.Server.Player do
  @behaviour Europa.Server.PlayerManager

  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Action
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Errors

  import Europa.Tools.Randomizer
  import Europa.Tools.Conf

  @type inventory :: list(Loot.Item.t())

  @stackable_items [:ammo, :supply]

  typedstruct do
    field :view_direction, Planet.direction(), enforce: true
    field :inventory, inventory(), enforce: true
    field :inventory_size, pos_integer(), enforce: true
    field :max_health, pos_integer(), enforce: true
    field :health, non_neg_integer(), enforce: true
    field :accuracy, pos_integer(), enforce: true
    field :efficiency, pos_integer(), enforce: true
    field :max_warm, pos_integer(), enforce: true
    field :warm, pos_integer(), enforce: true
    field :stand_on, Planet.tile(), enforce: true
    field :weapon_uuid, Loot.uuid()
    field :helmet_uuid, Loot.uuid()
    field :suit_uuid, Loot.uuid()
    field :boots_uuid, Loot.uuid()
  end

  @impl true
  def new do
    max_health = max_health()
    max_warm = max_warm()

    %__MODULE__{
      view_direction: Planet.allowed_directions() |> Enum.random(),
      inventory: [],
      inventory_size: inventory_size(),
      max_health: max_health,
      health: health(max_health),
      accuracy: accuracy(),
      efficiency: efficiency(),
      max_warm: max_warm(),
      warm: warm(max_warm),
      stand_on: Planet.snow()
    }
  end

  @impl true
  def readable_stats(%__MODULE__{} = player) do
    equiped_weapon =
      case get_equiped_weapon(player) do
        {:ok, weapon} -> weapon.name
        _ -> gettext("No")
      end

    equiped_helmet =
      case get_equiped_helmet(player) do
        {:ok, helmet} -> helmet.name
        _ -> gettext("No")
      end

    equiped_suit =
      case get_equiped_suit(player) do
        {:ok, suit} -> suit.name
        _ -> gettext("No")
      end

    equiped_boots =
      case get_equiped_boots(player) do
        {:ok, boots} -> boots.name
        _ -> gettext("No")
      end

    [
      {gettext("Health"), "#{player.health}/#{player.max_health}"},
      {gettext("Warm"), "#{player.warm}/#{player.max_warm}"},
      {gettext("Inventory"), "#{Enum.count(player.inventory)}/#{player.inventory_size}"},
      {gettext("Accuracy"), player.accuracy},
      {gettext("Efficiency"), player.efficiency},
      {gettext("Weapon"), equiped_weapon},
      {gettext("Helmet"), equiped_helmet},
      {gettext("Suit"), equiped_suit},
      {gettext("Boots"), equiped_boots}
    ]
  end

  @impl true
  def change_view_direction(%__MODULE__{} = player, new_direction) do
    if new_direction in Planet.allowed_directions() do
      struct(player, view_direction: new_direction)
    else
      player
    end
  end

  @impl true
  def stand_on(%__MODULE__{} = player, tile) do
    struct(player, stand_on: tile)
  end

  @impl true
  def add_item(%__MODULE__{} = player, item) do
    if Loot.Item.item_type(item) in @stackable_items && already_have_such_item?(player.inventory, item) do
      stack_items(player, item)
    else
      do_add_item(player, item)
    end
  end

  @impl true
  def equip_item(%__MODULE__{} = player, item_uuid) do
    with {:ok, item} <- find_item(player.inventory, item_uuid),
         {:ok, updated_item} <- Loot.Item.equip(item) do
      do_equip_or_unequip_item(player, updated_item)
    end
  end

  @impl true
  def unequip_item(%__MODULE__{} = player, item_uuid) do
    with {:ok, item} <- find_item(player.inventory, item_uuid),
         {:ok, updated_item} <- Loot.Item.unequip(item) do
      do_equip_or_unequip_item(player, updated_item)
    end
  end

  @impl true
  def update_item(%__MODULE__{inventory: inventory} = player, updated_item) do
    updated_inventory =
      Enum.map(inventory, fn item ->
        if item.uuid == updated_item.uuid do
          updated_item
        else
          item
        end
      end)

    struct(player, inventory: updated_inventory)
  end

  @impl true
  def delete_item(%__MODULE__{inventory: inventory} = player, item_to_delete) do
    updated_inventory = Enum.reject(inventory, fn item -> item.uuid == item_to_delete.uuid end)
    struct(player, inventory: updated_inventory)
  end

  @impl true
  def get_equiped_weapon(%__MODULE__{weapon_uuid: nil}) do
    {:error, :no_weapon}
  end

  def get_equiped_weapon(%__MODULE__{weapon_uuid: weapon_uuid} = player) do
    with {:error, :not_found} <- find_item(player.inventory, weapon_uuid) do
      {:error, :no_weapon}
    end
  end

  @impl true
  def get_equiped_helmet(%__MODULE__{helmet_uuid: nil}) do
    {:error, :no_helmet}
  end

  def get_equiped_helmet(%__MODULE__{helmet_uuid: helmet_uuid} = player) do
    with {:error, :not_found} <- find_item(player.inventory, helmet_uuid) do
      {:error, :no_helmet}
    end
  end

  @impl true
  def get_equiped_suit(%__MODULE__{suit_uuid: nil}) do
    {:error, :no_suit}
  end

  def get_equiped_suit(%__MODULE__{suit_uuid: suit_uuid} = player) do
    with {:error, :not_found} <- find_item(player.inventory, suit_uuid) do
      {:error, :no_suit}
    end
  end

  @impl true
  def get_equiped_boots(%__MODULE__{boots_uuid: nil}) do
    {:error, :no_boots}
  end

  def get_equiped_boots(%__MODULE__{boots_uuid: boots_uuid} = player) do
    with {:error, :not_found} <- find_item(player.inventory, boots_uuid) do
      {:error, :no_boots}
    end
  end

  @impl true
  def find_weapon_ammo(%__MODULE__{} = player, %Loot.Weapon{} = weapon) do
    ammo =
      Enum.find(player.inventory, fn
        %Weapon.Ammo{caliber: caliber} when caliber == weapon.caliber -> true
        _ -> false
      end)

    case ammo do
      %Weapon.Ammo{} = ammo ->
        {:ok, ammo}

      _ ->
        {:error, :no_ammo}
    end
  end

  @impl true
  def take_damage(%__MODULE__{} = player, damage) when is_integer(damage) and damage > 0 do
    updated_health = max(0, player.health - damage)
    struct(player, health: updated_health)
  end

  @impl true
  def reload_weapon(%__MODULE__{} = player) do
    with {:ok, weapon} <- get_equiped_weapon(player),
         :ok <- Weapon.check_reload_needed(weapon),
         {:ok, ammo} <- find_weapon_ammo(player, weapon) do
      do_reload_weapon(player, weapon, ammo)
    end
  end

  @impl true
  def unload_weapon(%__MODULE__{} = player, weapon_uuid) do
    with {:ok, %Weapon{} = weapon} <- find_item(player.inventory, weapon_uuid),
         {:ok, {updated_weapon, ammo}} <- Weapon.unload(weapon),
         {:ok, updated_player} <- player |> update_item(updated_weapon) |> add_item(ammo) do
      {:ok, updated_player, updated_weapon}
    end
  end

  @impl true
  def consume_supply(%__MODULE__{} = player, supply_uuid) do
    with {:ok, supply} <- find_item(player.inventory, supply_uuid) do
      do_consume_supply(player, supply)
    end
  end

  @impl true
  def get_inventory(%__MODULE__{inventory: inventory}, :all), do: inventory

  def get_inventory(%__MODULE__{inventory: inventory}, items_type) do
    Enum.filter(inventory, fn item -> Loot.Item.item_type(item) == items_type end)
  end

  @impl true
  def tick(%__MODULE__{} = player, moves_count) when moves_count > 0 do
    do_tick(player, moves_count)
  end

  def tick(player, _), do: {:ok, player, []}

  ### PRIVATE ###

  defp do_tick(player, moves_count) do
    do_tick(player, moves_count, [])
  end

  defp do_tick(player, 0, actions) do
    {:ok, player, actions}
  end

  defp do_tick(player, moves_count, actions) do
    ticks = [
      fn player -> get_cold(player) end
    ]

    {updated_player, actions} =
      Enum.reduce(ticks, {player, actions}, fn tick_fn, {player, actions} ->
        {updated_player, new_actions} = tick_fn.(player)
        {updated_player, actions ++ new_actions}
      end)

    do_tick(updated_player, moves_count - 1, actions)
  end

  defp get_cold(%__MODULE__{warm: 0} = player) do
    if m_to_n?(1, 10) do
      {take_damage(player, 1), [Action.new(:player, :frostbite)]}
    else
      {player, []}
    end
  end

  defp get_cold(%__MODULE__{max_warm: max_warm, warm: warm} = player) do
    is_get_colder =
      if m_to_n?(warm, max_warm) do
        if m_to_n?(1, 10) do
          false
        else
          true
        end
      else
        true
      end

    if is_get_colder do
      {struct(player, warm: max(player.warm - 1, 0)), [Action.new(:player, :get_cold)]}
    else
      {player, []}
    end
  end

  defp do_consume_supply(%__MODULE__{} = player, %Supply{} = supply) do
    stats_changes = Loot.Item.player_stats_changes(supply)

    updated_supply = Supply.decrease_count(supply)

    updated_player =
      if updated_supply.count > 0 do
        player
        |> increase_attrs(stats_changes)
        |> update_item(updated_supply)
      else
        player
        |> increase_attrs(stats_changes)
        |> delete_item(supply)
      end

    {:ok, updated_player, updated_supply}
  end

  defp do_consume_supply(_player, _supply), do: {:error, %Errors.NotApplicableError{}}

  defp do_add_item(player, item) do
    if Enum.count(player.inventory) < player.inventory_size do
      {:ok, struct(player, inventory: [item | player.inventory])}
    else
      {:error, :full_inventory}
    end
  end

  defp do_reload_weapon(player, weapon, ammo) do
    with {:ok, rounds_needed} <- Weapon.rounds_to_full_magazine(weapon) do
      ammo_count = ammo.count

      if ammo_count > rounds_needed do
        updated_weapon = Weapon.add_rounds(weapon, rounds_needed)
        updated_ammo = Ammo.decrease_count(ammo, rounds_needed)

        updated_player =
          player
          |> update_item(updated_weapon)
          |> update_item(updated_ammo)

        {:ok, updated_player, updated_weapon}
      else
        rounds_count = min(ammo_count, rounds_needed)
        updated_weapon = Weapon.add_rounds(weapon, rounds_count)

        updated_player =
          player
          |> update_item(updated_weapon)
          |> delete_item(ammo)

        {:ok, updated_player, updated_weapon}
      end
    end
  end

  defp already_have_such_item?(inventory, item) do
    inventory
    |> Enum.filter(fn i ->
      item_type = Loot.Item.item_type(i)
      item_type in @stackable_items && item_type == Loot.Item.item_type(item)
    end)
    |> Enum.any?(fn inventory_item ->
      case Loot.Item.item_type(inventory_item) do
        :ammo -> inventory_item.caliber == item.caliber
        _ -> inventory_item.name == item.name
      end
    end)
  end

  defp stack_items(%__MODULE__{} = player, item) do
    updated_inventory =
      Enum.map(player.inventory, fn
        %Weapon.Ammo{caliber: caliber} = inventory_ammo when caliber == item.caliber ->
          struct(inventory_ammo, count: inventory_ammo.count + item.count)

        %Supply{type: type, name: name} = inventory_supply when name == item.name and type == item.type ->
          struct(inventory_supply, count: inventory_supply.count + item.count)

        item ->
          item
      end)

    {:ok, struct(player, inventory: updated_inventory)}
  end

  defp do_equip_or_unequip_item(player, updated_item) do
    current_item_attrs = get_current_item_attrs(player, updated_item)

    stats_changes =
      if updated_item.equiped do
        Loot.Item.player_stats_changes(updated_item)
      else
        %{}
      end

    updated_inventory =
      Enum.map(player.inventory, fn item ->
        cond do
          item.uuid == updated_item.uuid ->
            updated_item

          Loot.Item.item_type(item) == Loot.Item.item_type(updated_item) && item.equiped ->
            {:ok, item} = Loot.Item.unequip(item)
            item

          true ->
            item
        end
      end)

    changed_params =
      case updated_item do
        %Loot.Weapon{equiped: true} -> [weapon_uuid: updated_item.uuid]
        %Loot.Helmet{equiped: true} -> [helmet_uuid: updated_item.uuid]
        %Loot.Suit{equiped: true} -> [suit_uuid: updated_item.uuid]
        %Loot.Boots{equiped: true} -> [boots_uuid: updated_item.uuid]
        %Loot.Weapon{equiped: false} -> [weapon_uuid: nil]
        %Loot.Helmet{equiped: false} -> [helmet_uuid: nil]
        %Loot.Suit{equiped: false} -> [suit_uuid: nil]
        %Loot.Boots{equiped: false} -> [boots_uuid: nil]
      end

    {:ok,
     struct(player, [inventory: updated_inventory] ++ changed_params)
     |> update_player_attrs(current_item_attrs, stats_changes)}
  end

  defp update_player_attrs(player, old_item_attrs, new_item_attrs) do
    player
    |> decrease_attrs(old_item_attrs)
    |> increase_attrs(new_item_attrs)
  end

  defp decrease_attrs(player, attrs) do
    Enum.reduce(attrs, player, fn {attr_name, attr_value}, player ->
      case attr_name do
        :inventory_size ->
          struct(player, inventory_size: player.inventory_size - attr_value)

        :accuracy ->
          struct(player, accuracy: player.accuracy - attr_value)

        :efficiency ->
          struct(player, efficiency: player.efficiency - attr_value)

        :max_health ->
          max_health = player.max_health - attr_value
          struct(player, max_health: max_health, health: min(player.health, max_health))

        :max_warm ->
          max_warm = player.max_warm - attr_value
          struct(player, max_warm: max_warm, warm: min(player.warm, max_warm))

        _ ->
          player
      end
    end)
  end

  defp increase_attrs(player, attrs) do
    Enum.reduce(attrs, player, fn {attr_name, attr_value}, player ->
      case attr_name do
        :inventory_size -> struct(player, inventory_size: player.inventory_size + attr_value)
        :accuracy -> struct(player, accuracy: player.accuracy + attr_value)
        :efficiency -> struct(player, efficiency: player.efficiency + attr_value)
        :max_health -> struct(player, max_health: player.max_health + attr_value)
        :health -> struct(player, health: min(player.max_health, player.health + attr_value))
        :max_warm -> struct(player, max_warm: player.max_warm + attr_value)
        :warm -> struct(player, warm: min(player.max_warm, player.warm + attr_value))
        _ -> player
      end
    end)
  end

  defp get_current_item_attrs(player, new_item) do
    uuid =
      case new_item do
        %Loot.Weapon{} -> player.weapon_uuid
        %Loot.Helmet{} -> player.helmet_uuid
        %Loot.Suit{} -> player.suit_uuid
        %Loot.Boots{} -> player.boots_uuid
      end

    case find_item(player.inventory, uuid) do
      {:ok, current_item} -> Loot.Item.player_stats_changes(current_item)
      _ -> %{}
    end
  end

  defp find_item(inventory, item_uuid) do
    case Enum.find(inventory, fn item -> item.uuid == item_uuid end) do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end

  defp inventory_size do
    from = fetch_config!([:random_params, :player, :inventory_size, :from])
    to = fetch_config!([:random_params, :player, :inventory_size, :to])

    m_to_n(from, to)
  end

  defp max_health do
    from = fetch_config!([:random_params, :player, :max_health, :from])
    to = fetch_config!([:random_params, :player, :max_health, :to])

    m_to_n(from, to)
  end

  defp health(max_health) do
    half_of_health = div(max_health, 2)
    m_to_n(half_of_health, max_health)
  end

  defp accuracy do
    from = fetch_config!([:random_params, :player, :accuracy, :from])
    to = fetch_config!([:random_params, :player, :accuracy, :to])

    m_to_n(from, to)
  end

  defp efficiency do
    from = fetch_config!([:random_params, :player, :efficiency, :from])
    to = fetch_config!([:random_params, :player, :efficiency, :to])

    m_to_n(from, to)
  end

  defp max_warm do
    from = fetch_config!([:random_params, :player, :max_warm, :from])
    to = fetch_config!([:random_params, :player, :max_warm, :to])

    m_to_n(from, to)
  end

  defp warm(max_warm) do
    half_of_warm = div(max_warm, 2)
    m_to_n(half_of_warm, max_warm)
  end
end
