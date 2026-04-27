defmodule EuropaWeb.GameCompotents do
  # coveralls-ignore-start
  use EuropaWeb, :html
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Object
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Characters.Character
  alias Europa.Server.Loot
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Loot.Item
  alias Europa.Server.Chat
  alias Europa.Tools.NumberHelpers

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @player Planet.player()

  @game_version Mix.Project.config()[:version] |> to_string()

  @move_up_keys fetch_config!([:control_bindings, :move_up])
  @move_down_keys fetch_config!([:control_bindings, :move_down])
  @move_left_keys fetch_config!([:control_bindings, :move_left])
  @move_right_keys fetch_config!([:control_bindings, :move_right])

  @interact_keys fetch_config!([:control_bindings, :interact])
  @loot_keys fetch_config!([:control_bindings, :loot])
  @inventory_keys fetch_config!([:control_bindings, :inventory])
  @reload_keys fetch_config!([:control_bindings, :reload])
  @control_hints_keys fetch_config!([:control_bindings, :control_hints])
  @close_keys fetch_config!([:control_bindings, :close])
  @shoot_keys fetch_config!([:control_bindings, :shoot])
  @scope_keys fetch_config!([:control_bindings, :scope])

  @max_thirst fetch_config!([:game_params, :player, :max_thirst])
  @max_hunger fetch_config!([:game_params, :player, :max_hunger])

  @low_health_ratio fetch_config!([:game_params, :player, :low_health_ratio])

  @tiles_image_names Tiles.image_names()

  @gif_tiles Tiles.gif_tiles()

  @open_tooltip_class "tooltip tooltip-open"

  def start_screen(assigns) do
    ~H"""
    <div class="w-full p-5 m-5 grid place-items-center">
      <button
        id="start_buttom"
        phx-click="start_game"
        class="btn btn-xl bg-gradient-to-r from-cyan-600 to-blue-700 border-none text-white font-display font-bold px-12 py-4 rounded-full btn-glow"
      >
        {gettext("Start game")}
      </button>
    </div>
    """
  end

  def game_field(assigns) do
    formatted_scope =
      Enum.map(assigns.scope, fn {{from_y, from_x}, {to_y, to_x}} ->
        %{from: "#tile_#{from_y}_#{from_x}", to: "#tile_#{to_y}_#{to_x}"}
      end)

    assigns = assign(assigns, scope: formatted_scope)

    ~H"""
    <div class="w-3/6 h-fit flex flex-col overflow-hidden bg-base-200 p-5 m-5 rounded-box shadow-md grid place-items-center">
      <%= for {row, x} <- Enum.with_index(@visible_planet) do %>
        <div class="flex gap-0">
          <%= for {tile, y} <- Enum.with_index(row) do %>
            <div class={speech_class(tile)} data-tip={speech(tile)}>
              <img
                id={"tile_#{x}_#{y}"}
                phx-hook="Tooltip"
                data-tooltip={tile_tooltip(tile, @player)}
                src={~p"/images/tiles/#{render_tile(tile, @player)}"}
                class="w-full h-full max-w-[30px] max-h-[30px] object-contain z-50"
              />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    <div
      id="scope-data"
      phx-hook="Scope"
      data-show_scope={"#{@show_scope}"}
      data-scopes={Jason.encode!(@scope)}
      data-stroke-color="black"
      data-stroke-width="2"
      data-marker-color="darkred"
    >
    </div>
    """
  end

  def chat(assigns) do
    ~H"""
    <div class="h-80 overflow-y-auto bg-base-200 p-5 rounded-box shadow-md text-xs">
      <%= for message <- Enum.reverse(@chat.messages) do %>
        <p class={"break-words p-1.5 #{chat_color(message)}"}>
          <span class="italic text-gray-400 text-[10px]">{message.id}.</span> {message.text}
        </p>
      <% end %>
    </div>
    """
  end

  def current_time(assigns) do
    ~H"""
    <div class="bg-base-200 p-3 rounded-box shadow-md text-sm">
      ⌚ {@current_time.time}, {gettext("day")} {@current_time.day}, {@current_time.year} {gettext("year AD")}
    </div>
    """
  end

  def player_stats(assigns) do
    ~H"""
    <div class={"bg-base-200 p-5 rounded-box shadow-md text-#{@text_size}"}>
      <ul class="grid grid-cols-2 grid-rows-3 gap-3">
        <li class={"#{health_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div class="tooltip" data-tip={gettext("Health")}>
            💙 {@player_stats.health}/{@player_stats.max_health}
          </div>
        </li>
        <li class={"#{warm_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div class="tooltip" data-tip={gettext("Warm")}>
            ❄️ {@player_stats.warm}/{@player_stats.max_warm}
          </div>
        </li>
        <li class={"#{inventory_stats_class(@player_stats)}"} {open_inventory_attrs()}>
          <div class="tooltip" data-tip={gettext("Inventory")}>
            💼 {@player_stats.inventory_weight}/{@player_stats.max_weight}
          </div>
        </li>
        <li class={"#{thirst_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div class="tooltip" data-tip={gettext("Thirst")}>
            💧 {@player_stats.thirst}
          </div>
        </li>
        <li>
          <div class="tooltip" data-tip={gettext("Accuracy")}>
            🎯 {@player_stats.accuracy}
          </div>
        </li>
        <li class={"#{hunger_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div class="tooltip" data-tip={gettext("Hunger")}>
            🍗 {@player_stats.hunger}
          </div>
        </li>
        <li>
          <div class="tooltip" data-tip={gettext("Efficiency")}>
            🦌 {@player_stats.efficiency}
          </div>
        </li>
        <li class={"#{radiation_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div class="tooltip" data-tip={gettext("Radiation")}>
            ☢️ {@player_stats.radiation}
          </div>
        </li>
      </ul>
    </div>
    """
  end

  def control_hints_link(assigns) do
    assigns = Map.put(assigns, :version, @game_version)

    ~H"""
    <div class="bg-base-200 p-5 rounded-box shadow-md text-xs">
      <.link phx-click="show_control_hints">{gettext("Control hints")}</.link>
    </div>
    <div class="p-1 text-center text-xs">
      <div class="inline-block text-neutral">
        v{@version}
      </div>
    </div>
    """
  end

  def equipment(assigns) do
    ~H"""
    <div class="h-80 bg-base-200 p-5 rounded-box shadow-md text-xs">
      <div class="grid grid-cols-2 gap-x-4">
        <div class="flex flex-col gap-y-0.5">
          <%= if @helmet do %>
            <img
              id={"helmet-#{@helmet.uuid}"}
              {open_inventory_attrs("helmet")}
              phx-hook="Tooltip"
              data-tooltip={item_tooltip(@helmet, @player)}
              src={~p"/images/#{@helmet.image_name <> ".png"}"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% else %>
            <img
              id="no-helmet"
              {open_inventory_attrs("helmet")}
              phx-hook="Tooltip"
              data-tooltip={gettext("No helmet")}
              src={~p"/images/no_helmet.png"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% end %>

          <%= if @suit do %>
            <img
              id={"suit-#{@suit.uuid}"}
              {open_inventory_attrs("suit")}
              phx-hook="Tooltip"
              data-tooltip={item_tooltip(@suit, @player)}
              src={~p"/images/#{@suit.image_name <> ".png"}"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% else %>
            <img
              id="no-suit"
              {open_inventory_attrs("suit")}
              phx-hook="Tooltip"
              data-tooltip={gettext("No suit")}
              src={~p"/images/no_suit.png"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% end %>

          <%= if @boots do %>
            <img
              id={"boots-#{@boots.uuid}"}
              {open_inventory_attrs("boots")}
              phx-hook="Tooltip"
              data-tooltip={item_tooltip(@boots, @player)}
              src={~p"/images/#{@boots.image_name <> ".png"}"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% else %>
            <img
              id="no-boots"
              {open_inventory_attrs("boots")}
              phx-hook="Tooltip"
              data-tooltip={gettext("No boots")}
              src={~p"/images/no_boots.png"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% end %>
        </div>

        <div class="flex items-center">
          <%= if @weapon do %>
            <img
              id={"weapon-#{@weapon.uuid}"}
              {open_inventory_attrs("weapon")}
              phx-hook="Tooltip"
              data-tooltip={item_tooltip(@weapon, @player)}
              src={~p"/images/#{@weapon.image_name <> ".png"}"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% else %>
            <img
              id="no-weapon"
              {open_inventory_attrs("weapon")}
              phx-hook="Tooltip"
              data-tooltip={gettext("No weapon")}
              src={~p"/images/no_weapon.png"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def ammo_info(assigns) do
    ~H"""
    <%= if @weapon do %>
      <div class="bg-base-200 p-5 rounded-box shadow-md text-xs" {open_inventory_attrs("ammo")}>
        <p class="tooltip" data-tip={"#{gettext("Loaded")}/#{gettext("Magazine size")}/#{gettext("In inventory")}"}>
          {@weapon.caliber}: {@weapon.rounds_loaded}/{@weapon.magazine_size}/{@ammo_count}
        </p>
      </div>
    <% end %>
    """
  end

  def control_hints(assigns) do
    assigns = assign(assigns, hints: control_hints())

    ~H"""
    <%= if @show_control_hints do %>
      <input type="checkbox" id="control_hints" class="modal-toggle" checked={true} phx-change="close_control_hints" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <h3 class="text-lg font-bold pb-2">{gettext("Control hints")}</h3>
          <ul class="list-inside space-y-2 text-sm">
            <%= for hint <- @hints do %>
              <li>{hint}</li>
            <% end %>
          </ul>

          <div class="modal-action">
            <label phx-click="close_control_hints" for="control_hints" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def inventory(assigns) do
    ~H"""
    <%= if @inventory do %>
      <input type="checkbox" id="inventory" class="modal-toggle h-screen" checked={true} phx-change="close_inventory" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto max-w-2xl">
          <h3 class="text-lg font-bold">
            {gettext("Inventory")} ({@player_stats.inventory_weight}/{@player_stats.max_weight}{gettext("kg")})
          </h3>
          <div class="p-2">
            <.player_stats player_stats={@player_stats} text_size="xs" />
          </div>
          <div role="tablist" class="tabs tabs-lift tabs-xs pb-3 pt-3">
            <a
              role="tab"
              class={"#{item_tab_class(:all, @inventory_type)}"}
              id="tab-all"
              {open_inventory_attrs()}
            >
              All
            </a>
            <%= for {item_type, item_type_name} <- Loot.allowed_item_types() do %>
              <a
                role="tab"
                class={"#{item_tab_class(item_type, @inventory_type)}"}
                id={"tab-#{item_type}"}
                {open_inventory_attrs(item_type)}
              >
                {item_type_name}
              </a>
            <% end %>
          </div>
          <%= if Enum.count(@inventory) > 0 do %>
            <ul class="list-disc list-inside space-y-2 text-sm">
              <%= for item <- @inventory do %>
                <div class="group relative">
                  <li
                    id={"loot_item_#{item.uuid}"}
                    phx-hook="Tooltip"
                    data-tooltip={item_tooltip(item, @player)}
                  >
                    {Item.composed_name(item)}
                    <%= if Item.consumable?(item) do %>
                      <div class="tooltip" data-tip={"#{gettext("Consume")}"}>
                        <.link phx-click="consume_supply" phx-value-uuid={"#{item.uuid}"}>💊</.link>
                      </div>
                    <% end %>
                    <%= if Item.equipable?(item) do %>
                      <%= if item.equiped do %>
                        <div class="tooltip" data-tip={"#{gettext("Unequip")}"}>
                          <.link phx-click="unequip_item" phx-value-uuid={"#{item.uuid}"}>🫳🏻</.link>
                        </div>
                      <% else %>
                        <div class="tooltip" data-tip={"#{gettext("Equip")}"}>
                          <.link phx-click="equip_item" phx-value-uuid={"#{item.uuid}"}>🛠️</.link>
                        </div>
                      <% end %>
                    <% end %>
                    <div class="dropdown" id={"item-#{item.uuid}-dropdown"} phx-hook="Dropdown">
                      <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">actions</div>
                      <ul tabindex="-1" class="dropdown-content menu bg-neutral rounded-box z-1 w-52 p-2 shadow-sm">
                        <li phx-click="drop_item" phx-value-uuid={"#{item.uuid}"}><a>{gettext("Drop")}</a></li>
                        <%= if Loot.Item.stackable?(item) do %>
                          <li phx-click="open_item_drop_menu" phx-value-uuid={"#{item.uuid}"}>
                            <a>{gettext("Drop partly")}</a>
                          </li>
                        <% end %>
                        <%= if weapon?(item) && item.rounds_loaded > 0 do %>
                          <li phx-click="unload_weapon" phx-value-uuid={"#{item.uuid}"}><a>{gettext("Unload")}</a></li>
                        <% end %>
                      </ul>
                    </div>
                  </li>
                </div>
              <% end %>
            </ul>
          <% else %>
            <p class="py-4 text-sm">Empty</p>
          <% end %>
          <div class="modal-action">
            <label phx-click="close_inventory" for="inventory" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def item_box(assigns) do
    ~H"""
    <%= if @item_box do %>
      <input type="checkbox" id="item_box" class="modal-toggle" checked={true} phx-change="close_item_box" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">{ItemBox.readable_name(@item_box)}</h3>
          <%= if Enum.count(@item_box.items) > 0 do %>
            <ul class="list-disc list-inside space-y-2 text-sm">
              <%= for item <- @item_box.items do %>
                <div class="group relative">
                  <li
                    id={"loot_item_#{item.uuid}"}
                    phx-hook="Tooltip"
                    data-tooltip={item_tooltip(item, @player)}
                  >
                    <.link phx-click="take_item" phx-value-uuid={"#{item.uuid}"}>
                      {Item.composed_name(item)}
                    </.link>
                    <%= if weapon?(item) && item.rounds_loaded > 0 do %>
                      <div class="dropdown" id={"item-#{item.uuid}-dropdown"} phx-hook="Dropdown">
                        <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">actions</div>
                        <ul tabindex="-1" class="dropdown-content menu bg-neutral rounded-box z-1 w-52 p-2 shadow-sm">
                          <li phx-click="unload_item_box_weapon" phx-value-uuid={"#{item.uuid}"}>
                            <a>{gettext("Unload")}</a>
                          </li>
                        </ul>
                      </div>
                    <% end %>
                  </li>
                </div>
              <% end %>
            </ul>
          <% else %>
            <p class="py-4 text-sm">Empty</p>
          <% end %>
          <div class="modal-action">
            <label phx-click="close_item_box" for="item_box" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def dialog(assigns) do
    ~H"""
    <%= if @dialog do %>
      <input type="checkbox" id="dialog" class="modal-toggle" checked={true} phx-change="close_dialog" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">{@dialog.npc.character.name}</h3>

          <ul class="list-disc list-inside space-y-2 text-sm mb-5">
            <li><b>{gettext("Age")}:</b> {@dialog.npc.character.current_age}</li>
            <li><b>{gettext("Gender")}:</b> {Character.readable_gender(@dialog.npc.character)}</li>
            <li><b>{gettext("Profession")}:</b> {@dialog.npc.character.profession}</li>
            <li><b>{gettext("Age at disaster")}:</b> {@dialog.npc.character.age_at_disaster}</li>
          </ul>

          <blockquote class="italic text-sm border-l-2 border-secondary p-2">
            {npc_story(@dialog.npc, @player)}
          </blockquote>

          <div class="modal-action">
            <label phx-click="close_dialog" for="dialog" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def item_drop_menu(assigns) do
    ~H"""
    <%= if @item_to_drop do %>
      <input type="checkbox" id="item_drop_menu" class="modal-toggle" checked={true} phx-change="close_item_drop_menu" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <h3 class="text-lg font-bold pb-3">{gettext("Drop")} {Loot.Item.composed_name(@item_to_drop)}</h3>
          <div>
            <input
              id="item_drop_count"
              type="number"
              class="input validator"
              name="item_drop_count"
              value={@item_drop_count}
              phx-hook="ItemDropChangeCount"
              phx-change="change_item_drop_count"
              required
              placeholder={gettext("How many?")}
              min="1"
              max={@item_to_drop.count}
              title={gettext("Must be between") <> " 1-#{@item_to_drop.count}"}
            />
            <p class="validator-hint">
              {gettext("Must be between")} 1-{@item_to_drop.count}
            </p>
            <button class="btn btn-neutral" phx-click="drop_item" phx-value-uuid={"#{@item_to_drop.uuid}"}>
              {gettext("Drop")}
            </button>
          </div>
          <div class="modal-action">
            <label phx-click="close_item_drop_menu" for="item_drop_menu" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  ### Helpers ###

  defp chat_color(%Chat.Message{category: category}) do
    case category do
      :story -> "text-info"
      :regular -> "text-primary"
      :warning -> "text-warning"
      :danger -> "text-error"
    end
  end

  defp render_tile(tile, player) do
    get_image_name(tile, player)
  end

  defp item_tab_class(tab, current_type) do
    if tab == current_type do
      "tab tab-active"
    else
      "tab"
    end
  end

  defp get_item_attrs(item, nil) do
    item
    |> Item.readable_attrs()
    |> Enum.map(fn {_attr, name, value} -> {name, value} end)
  end

  defp get_item_attrs(item, current_item) do
    item_attrs = Item.readable_attrs(item)
    current_item_attrs = Item.readable_attrs(current_item)

    Enum.with_index(item_attrs, fn {attr, name, value}, index ->
      {_current_attr, _current_name, current_value} = Enum.at(current_item_attrs, index)

      cond do
        (is_binary(value) or is_atom(value)) && value != current_value ->
          {name, "#{value} (diff)"}

        is_number(value) && value > current_value && attr not in Item.negative_attrs(item) ->
          {name, "#{value} (+#{maybe_round_number(value - current_value)})", "text-blue-500"}

        is_number(value) && value > current_value && attr in Item.negative_attrs(item) ->
          {name, "#{value} (+#{maybe_round_number(value - current_value)})", "text-red-500"}

        is_number(value) && value < current_value && attr not in Item.negative_attrs(item) ->
          {name, "#{value} (-#{maybe_round_number(current_value - value)})", "text-red-500"}

        is_number(value) && value < current_value && attr in Item.negative_attrs(item) ->
          {name, "#{value} (-#{maybe_round_number(current_value - value)})", "text-blue-500"}

        true ->
          {name, value}
      end
    end)
  end

  defp weapon?(%Loot.Weapon{}), do: true
  defp weapon?(_), do: false

  defp item_tooltip(item, player) do
    current_item =
      case Item.item_type(item) do
        :weapon -> get_player_weapon(player)
        :melee_weapon -> get_player_melee_weapon(player)
        :helmet -> get_player_helmet(player)
        :suit -> get_player_suit(player)
        :boots -> get_player_boots(player)
        _ -> nil
      end

    item
    |> get_item_attrs(current_item)
    |> to_ul()
  end

  defp tile_tooltip(tile, player) do
    case tile do
      @player ->
        player
        |> Player.readable_stats()
        |> to_ul()

      %Enemy{} = enemy ->
        enemy
        |> Enemy.readable_stats()
        |> to_ul()

      %Npc{} = npc ->
        Npc.readable_stats(npc) |> to_ul()

      tile ->
        Planet.readable_tile_name(tile)
    end
  end

  defp to_ul(list) do
    attrs =
      Enum.map_join(list, fn
        {name, value, li_class} -> ~s|<li class="#{li_class}"><b>#{name}:</b> #{value}</li>|
        {name, value} -> ~s|<li><b>#{name}:</b> #{value}</li>|
      end)

    ~s|<ul class="list-disc list-inside space-y-2">| <> attrs <> ~s|</ul>|
  end

  defp get_image_name(:player, %Player{view_direction: view_direction, stand_on: stand_on}) do
    view_direction = Atom.to_string(view_direction)
    "player_#{view_direction}_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :bunch, stand_on: stand_on}, _) do
    "monster_corpse_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :monster_body, stand_on: stand_on}, _) do
    "monster_corpse_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :human_body, stand_on: stand_on}, _) do
    "human_corpse_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :crashed_shuttle, stand_on: stand_on}, _) do
    "crashed_shuttle_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :cupboard, stand_on: stand_on}, _) do
    "cupboard_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :refrigerator, stand_on: stand_on}, _) do
    "refrigerator_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{stand_on: stand_on}, _) do
    "factory_box_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%Enemy{image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%Npc{stand_on: stand_on}, _) do
    "player_down_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%Object{gif_tile?: true, image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.gif"
  end

  defp get_image_name(%Object{image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(tile, _) do
    if tile in @gif_tiles do
      landscape_name(tile) <> ".gif"
    else
      landscape_name(tile) <> ".png"
    end
  end

  defp landscape_name(%ItemBox{stand_on: stand_on}),
    do: "monster_corpse_#{landscape_name(stand_on)}"

  defp landscape_name(tile) do
    Map.get(@tiles_image_names, tile)
  end

  defp get_player_weapon(player) do
    case Player.get_equiped_weapon(player) do
      {:ok, weapon} -> weapon
      _ -> nil
    end
  end

  defp get_player_melee_weapon(player) do
    case Player.get_equiped_melee_weapon(player) do
      {:ok, melee_weapon} -> melee_weapon
      _ -> nil
    end
  end

  defp get_player_helmet(player) do
    case Player.get_equiped_helmet(player) do
      {:ok, helmet} -> helmet
      _ -> nil
    end
  end

  defp get_player_suit(player) do
    case Player.get_equiped_suit(player) do
      {:ok, suit} -> suit
      _ -> nil
    end
  end

  defp get_player_boots(player) do
    case Player.get_equiped_boots(player) do
      {:ok, boots} -> boots
      _ -> nil
    end
  end

  defp control_hints do
    [
      control_hint(gettext("Move/punch up"), @move_up_keys),
      control_hint(gettext("Move/punch down"), @move_down_keys),
      control_hint(gettext("Move/punch left"), @move_left_keys),
      control_hint(gettext("Move/punch right"), @move_right_keys),
      control_hint(gettext("Interact with environment"), @interact_keys),
      control_hint(gettext("Loot"), @loot_keys),
      control_hint(gettext("Inventory"), @inventory_keys),
      control_hint(gettext("Control hints"), @control_hints_keys),
      control_hint(gettext("Shoot"), @shoot_keys),
      control_hint(gettext("Reload weapon"), @reload_keys),
      control_hint(gettext("Show/hide scope"), @scope_keys),
      control_hint(gettext("Close"), @close_keys)
    ]
  end

  defp control_hint(action, keys) do
    assigns = %{action: action, keys: filter_keys(keys)}

    ~H"""
    <%= for key <- @keys do %>
      <kbd class="kbd kbd-sm">{maybe_format_key_name(key)}</kbd>
    <% end %>
    - {@action}
    """
  end

  defp filter_keys(keys) do
    Enum.reduce(keys, [], fn key, acc ->
      upcased_key = String.upcase(key)

      if upcased_key in acc do
        acc
      else
        acc ++ [upcased_key]
      end
    end)
  end

  defp maybe_format_key_name("ARROWUP"), do: "▲"
  defp maybe_format_key_name("ARROWDOWN"), do: "▼"
  defp maybe_format_key_name("ARROWLEFT"), do: "◀︎"
  defp maybe_format_key_name("ARROWRIGHT"), do: "▶︎"
  defp maybe_format_key_name(key), do: key

  defp open_inventory_attrs(type \\ nil) do
    attrs = ["phx-click": open_inventory_click()]

    if type do
      attrs ++ ["phx-value-type": type]
    else
      attrs
    end
  end

  defp open_inventory_click do
    JS.dispatch("js:play-sound", detail: %{name: "click"}) |> JS.push("open_inventory")
  end

  defp health_stats_class(player_stats) do
    if player_stats.health == 0 ||
         (player_stats.health > 0 && player_stats.health / player_stats.max_health <= @low_health_ratio) do
      "text-red-500"
    else
      ""
    end
  end

  defp inventory_stats_class(player_stats) do
    if player_stats.inventory_weight > player_stats.max_weight do
      "text-red-500"
    else
      ""
    end
  end

  defp thirst_stats_class(player_stats) do
    if player_stats.thirst > 0 && @max_thirst / player_stats.thirst <= 1.8 do
      "text-red-500"
    else
      ""
    end
  end

  defp hunger_stats_class(player_stats) do
    if player_stats.hunger > 0 && @max_hunger / player_stats.hunger <= 1.8 do
      "text-red-500"
    else
      ""
    end
  end

  defp radiation_stats_class(player_stats) do
    if player_stats.radiation > 0 do
      "text-red-500"
    else
      ""
    end
  end

  defp warm_stats_class(player_stats) do
    if player_stats.warm < 30 do
      "text-red-500"
    else
      ""
    end
  end

  defp npc_story(%Npc{character: %Character{} = character} = npc, player) do
    case Character.random_special_story(character, player.character) do
      nil -> npc.story
      special_story -> special_story
    end
  end

  defp speech_class(%Npc{character: %Character{short_phrases: []}}), do: ""

  defp speech_class(%Npc{}) do
    if m_to_n?(1, 3) do
      @open_tooltip_class
    else
      ""
    end
  end

  defp speech_class(%Enemy{}) do
    if m_to_n?(1, 10) do
      @open_tooltip_class
    else
      ""
    end
  end

  defp speech_class(_), do: ""

  defp speech(%Npc{character: character}) do
    Character.short_phrase(character)
  end

  defp speech(%Enemy{}) do
    monster_sounds = [
      gettext("Raaaar!"),
      gettext("Grrr!"),
      gettext("Grrraaah!"),
      gettext("#&^!&#")
    ]

    Enum.random(monster_sounds)
  end

  defp speech(_), do: ""

  defp maybe_round_number(number) when is_float(number) do
    NumberHelpers.round(number, 2)
  end

  defp maybe_round_number(number) do
    number
  end

  # coveralls-ignore-stop
end
