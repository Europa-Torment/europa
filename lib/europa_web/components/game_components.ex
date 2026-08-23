defmodule EuropaWeb.GameCompotents do
  # coveralls-ignore-start
  use EuropaWeb, :html
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Squad
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.PlayerManager
  alias Europa.Server.Player
  alias Europa.Server.Player.Diseases.Disease
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Characters.Character
  alias Europa.Server.Characters.Profession
  alias Europa.Server.Loot
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Chat
  alias Europa.Server.Compass
  alias Europa.Tools.NumberHelpers

  import Europa.Tools.Conf

  @player Planet.player()

  @game_version Mix.Project.config()[:version] |> to_string()

  @move_up_keys fetch_config!([:control_bindings, :move_up]).keys
  @move_down_keys fetch_config!([:control_bindings, :move_down]).keys
  @move_left_keys fetch_config!([:control_bindings, :move_left]).keys
  @move_right_keys fetch_config!([:control_bindings, :move_right]).keys

  @interact_keys fetch_config!([:control_bindings, :interact]).keys
  @loot_keys fetch_config!([:control_bindings, :loot]).keys
  @inventory_keys fetch_config!([:control_bindings, :inventory]).keys
  @reload_keys fetch_config!([:control_bindings, :reload]).keys
  @control_hints_keys fetch_config!([:control_bindings, :control_hints]).keys
  @close_keys fetch_config!([:control_bindings, :close]).keys
  @shoot_keys fetch_config!([:control_bindings, :shoot]).keys
  @aim_keys fetch_config!([:control_bindings, :aim]).keys
  @zoom_keys fetch_config!([:control_bindings, :zoom]).keys
  @compass_keys fetch_config!([:control_bindings, :compass]).keys
  @map_keys fetch_config!([:control_bindings, :map]).keys
  @squad_keys fetch_config!([:control_bindings, :squad]).keys
  @skip_turn_keys fetch_config!([:control_bindings, :skip_turn]).keys

  @max_thirst fetch_config!([:game_params, :player, :max_thirst])
  @max_hunger fetch_config!([:game_params, :player, :max_hunger])

  @low_health_ratio fetch_config!([:game_params, :player, :low_health_ratio])

  @craft_moves_count fetch_config!([:game_params, :craft_moves_count])

  @compass_max_description_length fetch_config!([Compass, :max_description_length])

  @tiles_image_names Tiles.image_names()

  @gif_tiles Tiles.gif_tiles()
  @lethal_tiles Tiles.lethal_tiles()
  @swimable_tiles Tiles.swimable_tiles()

  @professions Profession.professions()

  def start_screen(assigns) do
    ~H"""
    <div class="w-full p-5 m-5 grid place-items-center">
      <%= if @connected? do %>
        <button
          id="start_buttom"
          phx-click="start_game"
          class="btn btn-pixel btn-xl bg-gradient-to-r from-cyan-600 to-blue-700 border-none text-white font-display font-bold px-12 py-4 rounded-none"
        >
          <.icon_image name="gamepad" /> {gettext("Ready")}
        </button>
        <span class="text-xs text-white/40 mt-4">{start_screen_tip()}</span>
      <% end %>
    </div>
    """
  end

  def game_field(assigns) do
    formatted_aim =
      Enum.map(assigns.aim, fn {{from_y, from_x}, {to_y, to_x}} ->
        %{from: "#tile_img_#{from_y}_#{from_x}", to: "#tile_img_#{to_y}_#{to_x}"}
      end)

    visible_planet =
      if assigns.zoom_mode do
        zoom_visible_planet(assigns.visible_planet, 9)
      else
        assigns.visible_planet
      end

    assigns = assign(assigns, aim: formatted_aim, visible_planet: visible_planet)

    ~H"""
    <div
      id="game-field"
      phx-hook="EventsProcessor"
      data-interval="750"
      class="w-3/6 h-fit flex flex-col overflow-hidden bg-base-200 p-5 m-5 shadow-md grid place-items-center"
    >
      <%= for {row, x} <- Enum.with_index(@visible_planet) do %>
        <div id={"row_#{x}"} class="flex flex-row gap-0 p-0 m-0 leading-none">
          <%= for {{{real_x, real_y}, tile}, y} <- Enum.with_index(row) do %>
            <div
              id={"tile_#{x}_#{y}"}
              phx-click="mouse_action"
              phx-value-x={real_x}
              phx-value-y={real_y}
              data-uid={tile_uid(tile)}
              class="p-0 m-0"
              style={"width: #{tile_image_size(@zoom_mode)}px; height: #{tile_image_size(@zoom_mode)}px; margin-bottom: -0.5px"}
            >
              <img
                id={"tile_img_#{x}_#{y}"}
                phx-hook="Tooltip"
                data-tooltip={tile_tooltip(tile, @player)}
                src={~p"/images/tiles/#{render_tile(tile, @player)}"}
                class="w-full h-full block object-cover z-50 p-0 m-0"
                style={"#{npc_color_filter(tile, @squad)}"}
              />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    <div
      id="aim-data"
      phx-hook="Aim"
      data-show_aim={"#{@player.aim_mode? && not @zoom_mode}"}
      data-aims={Jason.encode!(@aim)}
      data-stroke-color="black"
      data-stroke-width="2"
      data-marker-color="darkred"
    >
    </div>
    """
  end

  def chat(assigns) do
    ~H"""
    <div
      id="chat"
      class="min-h-[40vh] max-h-[40vh] overflow-y-auto bg-base-200 p-5 shadow-md text-xs"
      phx-hook="ScrollOnChange"
    >
      <%= for message <- Enum.reverse(@chat.messages) do %>
        <p class={"break-words p-1.5 #{chat_color(message)}"}>
          <span class="italic text-gray-400 text-[10px]">{message.id}.</span> {message.text}
          <.moves_count moves_count={message.moves_count} />
        </p>
      <% end %>
    </div>
    """
  end

  def planet_info(assigns) do
    ~H"""
    <div class="bg-base-200 p-3 shadow-md text-sm">
      <ul class="inline-flex items-center gap-2">
        <li>
          <.icon_image name="clock" /> {@current_time.time}, {gettext("day")} {@current_time.day}, {@current_time.year} {gettext(
            "year AD"
          )}
        </li>
        <li class="tooltip" data-tip={gettext("Ambient temperature")}>
          <.icon_image name="warm" />{@player.ambient_temperature}°
        </li>
      </ul>
    </div>
    """
  end

  def player_diseases_indicator(assigns) do
    {text, color} = diseases_info(assigns.player.diseases)
    assigns = assign(assigns, text: text, color: color)

    ~H"""
    <div id="diseases_indicator" class="bg-base-200 p-3 shadow-md text-sm" style={"color: #{@color}"}>
      <.link phx-click="open_diseases_menu">{@text}</.link>
    </div>
    """
  end

  def squad_indicator(assigns) do
    assigns =
      assign(assigns, members_count: Enum.count(assigns.squad.members), satisfaction: Squad.satisfaction(assigns.squad))

    ~H"""
    <div id="squad_indicator" class="bg-base-200 p-3 shadow-md text-sm">
      <.link phx-click="open_squad_menu">
        {gettext("Squad")} ({@members_count})
        <span class="text-xs" style={"color: #{squad_satisfaction_color(@satisfaction)}"}>{@satisfaction}%</span>
      </.link>
    </div>
    """
  end

  def new_diseases_info(assigns) do
    ~H"""
    <%= if @new_diseases do %>
      <input
        type="checkbox"
        id="new_diseases_info"
        class="modal-toggle"
        checked={true}
        phx-change="close_new_diseases_info"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <h3 class="text-lg font-bold pb-2">{gettext("You have developed new diseases")}:</h3>
          <ul class="list-disc list-inside space-y-2 text-md">
            <%= for disease <- @new_diseases do %>
              <li id={"new_disease_#{disease.id}"} phx-hook="Tooltip" data-tooltip={disease_tooltip(disease)}>
                {Disease.readable_name(disease)}
              </li>
            <% end %>
          </ul>

          <div class="text-secondary text-sm mt-5">
            {gettext(
              "Now, to maintain a normal condition, you need to take supplies that alleviate given diseases, or wait for recovery"
            )}.
          </div>

          <div class="modal-action">
            <label phx-click="close_new_diseases_info" for="new_diseases_info" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def diseases_menu(assigns) do
    ~H"""
    <%= if @show_diseases_menu do %>
      <input
        type="checkbox"
        id="diseases_menu"
        class="modal-toggle"
        checked={true}
        phx-change="close_diseases_menu"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <%= if Enum.empty?(@player.diseases) do %>
            <h3 class="text-lg font-bold pb-2">{gettext("You are not sick with anything")}</h3>
          <% else %>
            <h3 class="text-lg font-bold pb-2">{gettext("You have the following diseases")}:</h3>
            <ul class="list-disc list-inside space-y-2 text-md">
              <%= for disease <- @player.diseases do %>
                <li id={"disease_#{disease.id}"} phx-hook="Tooltip" data-tooltip={disease_tooltip(disease)}>
                  {Disease.readable_name(disease)}
                  <span class="text-xs" style={"color: #{disease_color(disease.satisfaction)}"}>
                    {disease.satisfaction}% {gettext("satisfied")}
                  </span>
                  <%= if disease.satisfaction == 0 do %>
                    <span class="text-xs text-secondary">
                      ({gettext("%{count} moves to recovery", count: disease.moves_to_recovery)})
                    </span>
                  <% end %>
                </li>
              <% end %>
            </ul>

            <div class="text-secondary text-xs mt-5">
              {gettext("Take the supplies you depend on to relieve symptoms or wait for recovery")}.
            </div>
          <% end %>

          <div class="modal-action">
            <label phx-click="close_diseases_menu" for="diseases_menu" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def player_stats(assigns) do
    ~H"""
    <div class={"bg-base-200 p-3 shadow-md text-#{@text_size}"}>
      <ul class="grid grid-cols-4 grid-rows-2 gap-0.8 sm:gap-1">
        <!-- все li-элементы без изменений -->
        <li class={"#{health_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div id={"health-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:health)}>
            <.link><.icon_image name="heart" /> {@player_stats.health}/{@player_stats.max_health}</.link>
          </div>
        </li>
        <li class={"#{inventory_stats_class(@player_stats)}"} {open_inventory_attrs()}>
          <div id={"inventory-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:inventory)}>
            <.link><.icon_image name="backpack" /> {@player_stats.inventory_weight}/{@player_stats.max_weight}</.link>
          </div>
        </li>
        <li class={"#{warm_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div id={"warm-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:warm)}>
            <.link><.icon_image name="warm" /> {@player_stats.warm}/{@player_stats.max_warm}</.link>
          </div>
        </li>
        <li>
          <div id={"accuracy-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:accuracy)}>
            <.link><.icon_image name="accuracy" /> {@player_stats.accuracy}</.link>
          </div>
        </li>
        <li class={"#{thirst_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div id={"thirst-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:thirst)}>
            <.link><.icon_image name="thirst" /> {@player_stats.thirst}</.link>
          </div>
        </li>
        <li class={"#{hunger_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div id={"hunger-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:hunger)}>
            <.link><.icon_image name="hunger" /> {@player_stats.hunger}</.link>
          </div>
        </li>
        <li class={"#{radiation_stats_class(@player_stats)}"} {open_inventory_attrs("supply")}>
          <div id={"radiation-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:radiation)}>
            <.link><.icon_image name="radiation" /> {@player_stats.radiation}</.link>
          </div>
        </li>
        <li>
          <div id={"efficiency-stat-#{@display_type}"} phx-hook="Tooltip" data-tooltip={stat_tooltip(:efficiency)}>
            <.link><.icon_image name="efficiency" /> {@player_stats.efficiency}</.link>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  def compass_link(assigns) do
    ~H"""
    <div class="bg-base-200 p-3 shadow-md text-sm">
      <.link phx-click="open_compass"><.icon_image name="compass" /> {gettext("Compass")}</.link>
    </div>
    """
  end

  def control_hints_link(assigns) do
    assigns = Map.put(assigns, :version, @game_version)

    ~H"""
    <div class="bg-base-200 p-3 shadow-md text-sm">
      <.link phx-click="show_control_hints"><.icon_image name="book" /> {gettext("Control hints")}</.link>
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
    <div class="w-fit h-auto bg-base-200 p-5 shadow-md text-xs">
      <div class="grid grid-cols-2 gap-x-4 justify-items-center content-start">
        <div class="flex flex-col gap-y-0.5">
          <%= if @helmet do %>
            <.item_image item={@helmet} player={@player} />
          <% else %>
            <.link>
              <img
                id="no-helmet"
                {open_inventory_attrs("helmet")}
                phx-hook="Tooltip"
                data-tooltip={gettext("No helmet")}
                src={~p"/images/equipment/helmets/no_helmet.png"}
                alt="4"
                class="bg-neutral max-w-full h-auto object-contain block mx-auto"
              />
            </.link>
          <% end %>

          <%= if @suit do %>
            <.item_image item={@suit} player={@player} />
          <% else %>
            <.link>
              <img
                id="no-suit"
                {open_inventory_attrs("suit")}
                phx-hook="Tooltip"
                data-tooltip={gettext("No suit")}
                src={~p"/images/equipment/suits/no_suit.png"}
                alt="4"
                class="bg-neutral max-w-full h-auto object-contain block mx-auto"
              />
            </.link>
          <% end %>

          <%= if @boots do %>
            <.item_image item={@boots} player={@player} />
          <% else %>
            <.link>
              <img
                id="no-boots"
                {open_inventory_attrs("boots")}
                phx-hook="Tooltip"
                data-tooltip={gettext("No boots")}
                src={~p"/images/equipment/boots/no_boots.png"}
                alt="4"
                class="bg-neutral max-w-full h-auto object-contain block mx-auto"
              />
            </.link>
          <% end %>
        </div>

        <div class="flex flex-col gap-y-0.5">
          <%= if @weapon do %>
            <.item_image item={@weapon} player={@player} />
          <% else %>
            <.link>
              <img
                id="no-weapon"
                {open_inventory_attrs("weapon")}
                phx-hook="Tooltip"
                data-tooltip={gettext("No weapon")}
                src={~p"/images/equipment/weapons/no_weapon.png"}
                alt="4"
                class="bg-neutral max-w-full h-auto object-contain block mx-auto"
              />
            </.link>
          <% end %>
          <%= if @melee_weapon do %>
            <.item_image item={@melee_weapon} player={@player} />
          <% else %>
            <.link>
              <img
                id="no-melee-weapon"
                {open_inventory_attrs("melee_weapon")}
                phx-hook="Tooltip"
                data-tooltip={gettext("No melee weapon")}
                src={~p"/images/equipment/melee_weapons/fist.png"}
                alt="4"
                class="bg-neutral max-w-full h-auto object-contain block mx-auto"
              />
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def item_image(assigns) do
    ~H"""
    <.link>
      <img
        id={"#{Loot.Item.item_type(@item)}-#{@item.uuid}"}
        {open_inventory_attrs("#{Loot.Item.item_type(@item)}")}
        phx-hook="Tooltip"
        data-tooltip={item_tooltip(@item, @player)}
        src={"#{item_image_path(@item)}"}
        alt="4"
        class="bg-neutral max-w-full h-auto object-contain block mx-auto"
      />
    </.link>
    """
  end

  def ammo_info(assigns) do
    ~H"""
    <%= if @weapon do %>
      <div
        style="display: inline-flex; align-items: center; gap: 0;"
        class="bg-base-200 p-3 shadow-md text-xs"
        {open_inventory_attrs("ammo")}
      >
        <p class="tooltip" data-tip={"#{gettext("Loaded")}/#{gettext("Magazine size")} (#{gettext("In inventory")})"}>
          <.link>
            <span class="text-lg"><.icon_image name="ammo" /></span> {@weapon.caliber}: {@weapon.rounds_loaded}/{@weapon.magazine_size} ({@ammo_count})
          </.link>
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

          <div class="text-secondary text-sm mt-5">
            {gettext("You can also perform most actions by left-clicking on the desired area of the game field.")}
          </div>

          <div class="modal-action">
            <label phx-click="close_control_hints" for="control_hints" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def inventory(assigns) do
    {equipped_implants, rest_items} =
      if assigns[:inventory_type] == :implant && assigns[:inventory] do
        Enum.split_with(assigns.inventory, fn implant -> implant.equipped end)
      else
        {[], assigns[:inventory]}
      end

    assigns =
      assign(assigns,
        inventory: rest_items,
        equipped_implants: equipped_implants,
        craft_moves_count: @craft_moves_count
      )

    ~H"""
    <%= if @inventory do %>
      <input type="checkbox" id="inventory" class="modal-toggle h-screen" checked={true} phx-change="close_inventory" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto max-w-2xl">
          <h3 class="text-lg font-bold">
            {gettext("Inventory")} ({@player_stats.inventory_weight}/{@player_stats.max_weight}{gettext("kg")})
            <button
              style="display: inline-flex; align-items: center; gap: 0;"
              class="btn btn-primary btn-sm"
              {open_craft_menu_attrs()}
            >
              <span class="text-lg"><.icon_image name="tool" /></span>{gettext("Craft items")}
            </button>
          </h3>
          <div class="p-2">
            <.player_stats player_stats={@player_stats} text_size="xs" display_type="inventory" />
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
          <%= if @inventory_type == :implant do %>
            <.equipped_implants implants={@equipped_implants} player={@player} craft_moves_count={@craft_moves_count} />
          <% end %>
          <%= if Enum.count(@inventory) > 0 do %>
            <ul class="list-disc list-inside space-y-2 text-sm">
              <%= for item <- @inventory do %>
                <.inventory_item item={item} player={@player} craft_moves_count={@craft_moves_count} />
              <% end %>
            </ul>
          <% else %>
            <p class="py-4 text-sm">{gettext("Empty")}</p>
          <% end %>
          <div class="modal-action">
            <label phx-click="close_inventory" for="inventory" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def inventory_item(assigns) do
    ~H"""
    <div class="group relative">
      <li>
        <span
          id={"loot_item_#{@item.uuid}"}
          phx-hook="Tooltip"
          data-tooltip={item_tooltip(@item, @player)}
        >
          {Item.composed_name(@item)}
        </span>
        <.item_quick_action item={@item} />
        <div class="dropdown dropdown-top" id={"item-#{@item.uuid}-dropdown"} phx-hook="Dropdown">
          <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">{gettext("actions")}</div>
          <ul tabindex="-1" class="dropdown-content menu bg-neutral z-1 w-52 p-2 shadow-sm">
            <%= if weapon?(@item) && @item.rounds_loaded < @item.magazine_size do %>
              <li phx-click="reload_weapon" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Reload")} <.moves_count moves_count={@item.reload_cost} /></a>
              </li>
            <% end %>
            <%= if weapon?(@item) && @item.rounds_loaded > 0 do %>
              <li phx-click="unload_weapon" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Unload")} <.moves_count moves_count={@item.reload_cost} /></a>
              </li>
            <% end %>
            <%= if Item.consumable?(@item) do %>
              <li phx-click="consume_supply" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Consume")}<.moves_count moves_count={@item.consume_cost} /></a>
              </li>
            <% end %>
            <%= if Item.usable?(@item) do %>
              <li phx-click="use_tool" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Use")}<.moves_count moves_count={@item.use_cost} /></a>
              </li>
            <% end %>
            <%= if Item.equipable?(@item) do %>
              <%= if @item.equipped do %>
                <li phx-click="unequip_item" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                  <a>{gettext("Unequip")}</a>
                </li>
              <% else %>
                <li phx-click="equip_item" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                  <a>{gettext("Equip")}</a>
                </li>
              <% end %>
            <% end %>
            <%= if Loot.item_disassemblable?(@item) do %>
              <li phx-click="disassemble_item" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Disassemble")}<.moves_count moves_count={@craft_moves_count} /></a>
              </li>
            <% end %>
            <%= if Loot.Item.stackable?(@item) do %>
              <li phx-click="open_item_to_squad_menu" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Give to squad")}</a>
              </li>
            <% else %>
              <li phx-click="give_item_to_squad" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Give to squad")}</a>
              </li>
            <% end %>
            <%= if Loot.Item.stackable?(@item) do %>
              <li phx-click="open_item_drop_menu" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Drop")}</a>
              </li>
            <% else %>
              <li phx-click="drop_item" phx-value-uuid={"#{@item.uuid}"} {dropdown_attrs()}>
                <a>{gettext("Drop")}</a>
              </li>
            <% end %>
          </ul>
        </div>
      </li>
    </div>
    """
  end

  def equipped_implants(assigns) do
    empty_implant_sockets = assigns.player.max_implants - Enum.count(assigns.player.implant_uuids)
    assigns = assign(assigns, empty_implant_sockets: empty_implant_sockets)

    ~H"""
    <div class="bg-base-200 p-5 shadow-md text-sm mb-3">
      <h2 class="text-lg mb-2">{gettext("Currently implanted")}</h2>
      <ul class="list-disc list-inside space-y-2 text-sm">
        <%= for implant <- @implants do %>
          <.inventory_item item={implant} player={@player} craft_moves_count={@craft_moves_count} />
        <% end %>
        <%= if @empty_implant_sockets > 0 do %>
          <%= for _ <- 1..@empty_implant_sockets do %>
            <li>
              <span class="text-secondary">{gettext("Empty implant socket")}</span>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
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
                  <li>
                    <.link
                      phx-click="take_item"
                      phx-value-uuid={"#{item.uuid}"}
                      id={"loot_item_#{item.uuid}"}
                      phx-hook="Tooltip"
                      data-tooltip={item_tooltip(item, @player)}
                    >
                      {Item.composed_name(item)}
                    </.link>
                    <%= if weapon?(item) && item.rounds_loaded > 0 do %>
                      <div class="dropdown dropdown-top" id={"item-#{item.uuid}-dropdown"} phx-hook="Dropdown">
                        <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">
                          {gettext("actions")}
                        </div>
                        <ul tabindex="-1" class="dropdown-content menu bg-neutral z-1 w-52 p-2 shadow-sm">
                          <li phx-click="unload_item_box_weapon" phx-value-uuid={"#{item.uuid}"} {dropdown_attrs()}>
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
            <p class="py-4 text-sm">{gettext("Empty")}</p>
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
          <div class="card w-full max-w-lg bg-base-100 shadow-xl border border-base-300 mb-3">
            <div class="card-body">
              <h2 class="card-title flex items-center gap-2">
                {@dialog.npc.character.name}
                <span class="badge badge-secondary text-xs">{Character.readable_fraction(@dialog.npc.character)}</span>
              </h2>

              <div class="grid grid-cols-[120px_1fr] gap-y-2 gap-x-4 mt-4 text-sm">
                <span class="font-semibold text-base-content/70">{gettext("Age")}</span>
                <span>{@dialog.npc.character.current_age}</span>

                <span class="font-semibold text-base-content/70">{gettext("Gender")}</span>
                <span>{Character.readable_gender(@dialog.npc.character)}</span>

                <span class="font-semibold text-base-content/70">{gettext("Profession")}</span>
                <span>
                  {Character.readable_profession(@dialog.npc.character)}
                  <button
                    id={"npc_#{@dialog.npc.uuid}_profession_info"}
                    phx-hook="Tooltip"
                    data-tooltip={profession_tooltip(@dialog.npc.character.profession)}
                    class="btn btn-circle btn-xs btn-outline"
                  >
                    ?
                  </button>
                </span>

                <span class="font-semibold text-base-content/70">{gettext("Age at disaster")}</span>
                <span>{age_at_disaster(@dialog.npc.character.age_at_disaster)}</span>
              </div>
            </div>
          </div>

          <%= unless @dialog.npc.character.not_playable? do %>
            <blockquote class="italic text-sm border-l-2 border-secondary p-2">
              {npc_story(@dialog.npc, @player)}
            </blockquote>
          <% end %>

          <ul class="list-disc list-inside space-y-2 text-sm mb-5 mt-2">
            <%= if !Squad.member?(@squad, @dialog.npc) && !Squad.declined?(@squad, @dialog.npc) do %>
              <li>
                <.link id="recruit_squad_member" class="text-primary" phx-click="recruit_squad_member">
                  {gettext("Invite to the squad")}
                </.link>
              </li>
            <% end %>
          </ul>

          <div class="modal-action">
            <label phx-click="close_dialog" for="dialog" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def interaction_confirmation(assigns) do
    assigns =
      if assigns.interaction_confirmation do
        assign(assigns, interaction_allowed?: interaction_allowed?(assigns.interaction_confirmation, assigns.player))
      else
        assigns
      end

    ~H"""
    <%= if @interaction_confirmation do %>
      <input
        type="checkbox"
        id="interaction_confirmation"
        class="modal-toggle"
        checked={true}
        phx-change="close_interaction_confirmation"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">{gettext("Confirm action")}</h3>

          <.interaction_confirmation_text interaction_confirmation={@interaction_confirmation} player={@player} />

          <div class="modal-action">
            <%= if @interaction_allowed? do %>
              <label
                phx-click="interact"
                phx-value-type="forced"
                phx-value-name={@transform_name}
                for="interaction_confirmation"
                class="btn btn-secondary"
              >
                {gettext("Confirm")}
              </label>
            <% end %>
            <label phx-click="close_interaction_confirmation" for="interaction_confirmation" class="btn">
              {gettext("Close")}
            </label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def interaction_confirmation_text(assigns) do
    case assigns.interaction_confirmation do
      :danger_action ->
        ~H"""
        <span class="text-md">{gettext("Commit a dangerous act?")}</span>
        """

      {:required_tools, tools} ->
        assigns = assign(assigns, required_tools: tools)

        ~H"""
        <.interaction_required_tools required_tools={@required_tools} player={@player} />
        """

      {:change, from, :delete} ->
        assigns = assign(assigns, from: from)

        ~H"""
        <span class="text-md">{gettext("%{from_name} will be delted", from_name: @from)}</span>
        """

      {:change, from, to} ->
        assigns = assign(assigns, from: from, to: to)

        ~H"""
        <span class="text-md">{gettext("%{from_name} will change to %{to_name}", from_name: @from, to_name: @to)}</span>
        """

      {:pick_transform, transforms} ->
        assigns = assign(assigns, transforms: transforms)

        ~H"""
        <.interaction_transforms_picker transforms={@transforms} />
        """

      _ ->
        ~H"""
        """
    end
  end

  def interaction_required_tools(assigns) do
    ~H"""
    <span class="text-md">{gettext("The action requires following items")}:</span>
    <br />

    <ul class="list-disc list-inside space-y-2 text-sm">
      <%= for tool <- @required_tools do %>
        <li class={required_tool_class(@player, tool)}>
          {interaction_tool_name(tool)}, {gettext("you have")}: {PlayerManager.tools_amount(@player, tool)}
        </li>
      <% end %>
    </ul>
    """
  end

  def interaction_transforms_picker(assigns) do
    ~H"""
    <ul class="list-disc list-inside space-y-1 text-sm pt-2">
      <%= for {transform, index} <- Enum.with_index(@transforms) do %>
        <li class="text-md font-bold">
          <.link id={"interact_transform_#{index}"} phx-click="interact" phx-value-name={"#{transform.name}"}>
            {transform.readable_name}
          </.link>
        </li>
      <% end %>
    </ul>
    """
  end

  def item_drop_menu(assigns) do
    ~H"""
    <%= if @item_to_drop do %>
      <input type="checkbox" id="item_drop_menu" class="modal-toggle" checked={true} phx-change="close_item_drop_menu" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <h3 class="text-lg font-bold pb-3">{gettext("Drop")} {Loot.Item.composed_name(@item_to_drop)}</h3>

          <.item_count_input
            id="item_drop_count"
            item={@item_to_drop}
            event="change_item_drop_count"
            value={@item_drop_count}
          />

          <button class="btn btn-secondary" phx-click="drop_item" phx-value-uuid={"#{@item_to_drop.uuid}"}>
            {gettext("Drop")}
          </button>

          <div class="modal-action">
            <label phx-click="close_item_drop_menu" for="item_drop_menu" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def item_to_squad_menu(assigns) do
    ~H"""
    <%= if @item_to_squad do %>
      <input
        type="checkbox"
        id="item_to_squad_menu"
        class="modal-toggle"
        checked={true}
        phx-change="close_item_to_squad_menu"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <h3 class="text-lg font-bold pb-3">{gettext("Give to squad")} {Loot.Item.composed_name(@item_to_squad)}</h3>

          <.item_count_input
            id="item_to_squad_count"
            item={@item_to_squad}
            event="change_item_to_squad_count"
            value={@item_to_squad_count}
          />

          <button class="btn btn-secondary" phx-click="give_item_to_squad" phx-value-uuid={"#{@item_to_squad.uuid}"}>
            {gettext("Give")}
          </button>

          <div class="modal-action">
            <label phx-click="close_item_to_squad_menu" for="item_to_squad_menu" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def item_disassemble_menu(assigns) do
    ~H"""
    <%= if @disassemble_items do %>
      <input
        type="checkbox"
        id="item_disassemble_menu"
        class="modal-toggle"
        checked={true}
        phx-change="close_item_disassemble_menu"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
          <h3 class="text-lg font-bold pb-3">{gettext("Item disassemble:")}</h3>
          <%= if Loot.Item.stackable?(@disassemble_item) do %>
            <.item_count_input
              id="disassemble_item_count"
              item={@disassemble_item}
              event="change_disassemble_item_count"
              value={@disassemble_item_count}
            />
          <% end %>
          <h4 class="text-md font-bold pb-3">{gettext("After disassembling you will receive following items:")}</h4>
          <div>
            <ul class="list-disc list-inside space-y-2 text-sm">
              <%= for item <- @disassemble_items do %>
                <li
                  id={"disassemble_item_#{item.uuid}"}
                  phx-hook="Tooltip"
                  data-tooltip={item_tooltip(item, @player)}
                >
                  {disassemble_item_name(item, @disassemble_item_count)}
                </li>
              <% end %>
            </ul>
          </div>
          <div class="modal-action">
            <label
              phx-click="confirm_item_disassemble"
              phx-value-uuid={"#{@disassemble_item.uuid}"}
              for="item_disassemble_menu"
              class="btn btn-secondary"
            >
              {gettext("Confirm")}
            </label>
            <label phx-click="close_item_disassemble_menu" for="item_disassemble_menu" class="btn">
              {gettext("Close")}
            </label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def item_count_input(assigns) do
    ~H"""
    <div class="mb-5">
      <div class="flex items-center gap-2">
        <input
          id={@id}
          type="number"
          class="input validator"
          name="item_drop_count"
          value={@value}
          phx-hook="InputChange"
          data-event={@event}
          data-min={1}
          data-max={@item.count}
          required
          placeholder={gettext("How many?")}
          min="1"
          max={@item.count}
        />
        <.set_input_max_button id={@id} />
      </div>
    </div>
    """
  end

  def set_input_max_button(assigns) do
    ~H"""
    <a
      href="#"
      phx-click="set_input_max"
      phx-value-id={@id}
      class="btn btn-sm btn-primary"
    >
      {gettext("max")}
    </a>
    """
  end

  def craft_menu(assigns) do
    assigns = assign(assigns, craft_moves_count: @craft_moves_count)

    ~H"""
    <%= if @blueprints do %>
      <input
        type="checkbox"
        id="craft_menu"
        class="modal-toggle"
        checked={true}
        phx-change="close_craft_menu"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">{gettext("Crafting items")}</h3>
          <div role="tablist" class="tabs tabs-lift tabs-xs pb-3 pt-3">
            <a
              role="tab"
              class={"#{item_tab_class(:all, @blueprints_type)}"}
              id="tab-all"
              {open_craft_menu_attrs()}
            >
              All
            </a>
            <%= for {item_type, item_type_name} <- Loot.allowed_item_types() do %>
              <a
                role="tab"
                class={"#{item_tab_class(item_type, @blueprints_type)}"}
                id={"tab-#{item_type}"}
                {open_craft_menu_attrs(item_type)}
              >
                {item_type_name}
              </a>
            <% end %>
          </div>
          <div>
            <ul class="list-disc list-inside space-y-2 text-sm">
              <%= if Enum.count(@blueprints) > 0 do %>
                <%= for %Loot.Blueprints.Blueprint{item: item, resources: required_resources} <- @blueprints do %>
                  <li
                    id={"craft_item_#{item.uuid}"}
                    phx-hook="Tooltip"
                    data-tooltip={craft_item_tooltip(item, required_resources, @player)}
                  >
                    {craft_item_name(item)}
                    <%= if PlayerManager.enough_resources?(@player, required_resources) do %>
                      <div class="tooltip" data-tip={"#{gettext("Create")}"}>
                        <.link phx-click="craft_item" phx-value-uuid={"#{item.uuid}"}>
                          <.icon_image name="tool" /> <.moves_count moves_count={@craft_moves_count} />
                        </.link>
                      </div>
                    <% end %>
                  </li>
                <% end %>
              <% else %>
                <p class="py-4 text-sm">{gettext("No blueprints")}</p>
              <% end %>
            </ul>
          </div>
          <div class="modal-action">
            <label phx-click="close_craft_menu" for="craft_menu" class="btn">
              {gettext("Close")}
            </label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def item_quick_action(assigns) do
    ~H"""
    <%= if Item.consumable?(@item) do %>
      <div class="tooltip" data-tip={"#{gettext("Consume")}"}>
        <.link phx-click="consume_supply" phx-value-uuid={"#{@item.uuid}"}>
          <.icon_image name="apple" /> <.moves_count moves_count={@item.consume_cost} />
        </.link>
      </div>
    <% end %>
    <%= if Item.usable?(@item) do %>
      <div class="tooltip" data-tip={"#{gettext("Use")}"}>
        <.link phx-click="use_tool" phx-value-uuid={"#{@item.uuid}"}>
          <.icon_image name={use_item_icon_image(@item)} /> <.moves_count moves_count={@item.use_cost} />
        </.link>
      </div>
    <% end %>
    <%= if Item.equipable?(@item) do %>
      <%= if @item.equipped do %>
        <div class="tooltip" data-tip={"#{gettext("Unequip")}"}>
          <.link phx-click="unequip_item" phx-value-uuid={"#{@item.uuid}"}><.icon_image name="cross" /></.link>
        </div>
      <% else %>
        <div class="tooltip" data-tip={"#{gettext("Equip")}"}>
          <.link phx-click="equip_item" phx-value-uuid={"#{@item.uuid}"}><.icon_image name="done" /></.link>
        </div>
      <% end %>
    <% end %>
    """
  end

  def moves_count(assigns) do
    ~H"""
    <%= if @moves_count > 0 do %>
      <span class="italic text-base-content text-[0.825rem]"><.icon_image name="dice" />{@moves_count}</span>
    <% end %>
    """
  end

  def map(assigns) do
    assigns =
      if assigns[:map] do
        assign(assigns, cols: length(hd(assigns.map)), rows: length(assigns.map))
      else
        assigns
      end

    ~H"""
    <%= if @map do %>
      <input type="checkbox" id="map" class="modal-toggle" checked={true} phx-change="close_map" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible mt-[5vh] max-w-2xl @container">
          <h3 class="text-lg font-bold pb-3">{gettext("Map of explored Europa")}</h3>

          <canvas
            id="map-canvas"
            phx-hook="Map"
            data-map={build_map_data(@map)}
            data-cols={@cols}
            data-rows={@rows}
            data-offset-x={@map_offset_x}
            data-offset-y={@map_offset_y}
            class="w-full max-w-2xl aspect-square max-h-[70vh] mx-auto"
          >
          </canvas>

          <div class="modal-action">
            <label phx-click="close_map" for="map" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def compass(assigns) do
    ~H"""
    <%= if @compass do %>
      <input type="checkbox" id="compass" class="modal-toggle" checked={true} phx-change="close_compass" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">{gettext("Compass")}</h3>

          <button class="btn btn-primary btn-sm mt-2 mb-2" {add_compass_target_attrs()}>
            <.icon_image name="compass" /> {gettext("Track current coord")}
          </button>

          <div class="text-xs">
            {gettext("Current coord")}: {coord(@current_coord)}
          </div>

          <.compass_current_target target={@compass.current_target} current_coord={@current_coord} />

          <.compass_targets targets={@compass.targets} current_coord={@current_coord} />

          <div class="modal-action">
            <label phx-click="close_compass" for="compass" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def compass_current_target(assigns) do
    ~H"""
    <div>
      <%= if @target do %>
        <div class="bg-base-200 p-5 shadow-md text-lg mt-2">
          <.compass_target target={@target} current_coord={@current_coord} is_current_target={true} />
        </div>
      <% end %>
    </div>
    """
  end

  def compass_targets(assigns) do
    ~H"""
    <%= unless Enum.empty?(@targets) do %>
      <ul class="list-disc list-inside space-y-2 mt-5 text-sm">
        <%= for target <- @targets do %>
          <li>
            <.compass_target target={target} current_coord={@current_coord} is_current_target={false} />
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end

  def compass_target(assigns) do
    assigns =
      if assigns.is_current_target do
        angle = coords_angle(assigns.current_coord, assigns.target.coord)
        style = "transform: rotate(#{angle}deg); position: absolute;"

        assign(assigns, style: style)
      else
        assigns
      end

    ~H"""
    <span id={"compass_target_#{@target.uuid}"} phx-hook="Tooltip" data-tooltip={@target.description}>
      {coord(@target.coord)}, {coords_distance(@target.coord, @current_coord)}
    </span>

    <%= if @is_current_target do %>
      <div class="tooltip" data-tip={"#{gettext("Unfollow")}"}>
        <.link phx-click="unfollow_compass_target"><.icon_image name="compass" /></.link>
      </div>
    <% else %>
      <div class="tooltip" data-tip={"#{gettext("Follow")}"}>
        <.link phx-click="follow_compass_target" phx-value-uuid={"#{@target.uuid}"}><.icon_image name="compass" /></.link>
      </div>
    <% end %>

    <div class="tooltip" data-tip={"#{gettext("Delete")}"}>
      <.link phx-click="delete_compass_target" phx-value-uuid={"#{@target.uuid}"}><.icon_image name="cross" /></.link>
    </div>

    <%= if @is_current_target do %>
      <span id="compass-arrow" class="ml-2" style={@style}>↑</span>
    <% end %>
    """
  end

  def compass_target_menu(assigns) do
    assigns = assign(assigns, max_description_length: @compass_max_description_length)

    ~H"""
    <%= if @compass_target_menu_active do %>
      <input
        type="checkbox"
        id="compass_target_menu"
        class="modal-toggle"
        checked={true}
        phx-change="close_compass_target_menu"
      />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">{gettext("Track coord")}</h3>

          <div>
            <input
              id="target_description"
              phx-hook="InputChange"
              data-event="change_compass_target_description"
              type="text"
              class="input validator"
              name="description"
              placeholder={gettext("Description, for example: Strong enemies")}
              maxlength={@max_description_length}
            />
            <p class="validator-hint">
              {gettext("Required field")}
            </p>
            <button class="btn btn-secondary" phx-click="add_compass_target">
              {gettext("Follow")}
            </button>
          </div>

          <div class="modal-action">
            <label phx-click="close_compass_target_menu" for="compass_target_menu" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def squad_menu(assigns) do
    assigns =
      assign(assigns, members_count: Enum.count(assigns.squad.members), satisfaction: Squad.satisfaction(assigns.squad))

    ~H"""
    <%= if @show_squad_menu do %>
      <input type="checkbox" id="squad_menu" class="modal-toggle" checked={true} phx-change="close_squad_menu" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl">
          <h3 class="text-lg font-bold pb-3">
            {gettext("Squad")}
            <span
              id="squad_satisfaction"
              phx-hook="Tooltip"
              data-tooltip={
                gettext(
                  "Squad status. Depends on the number of resources and members. The higher this value, the more attractive your squad is for new members to join."
                )
              }
              class="text-xs text-secondary"
              style={"color: #{squad_satisfaction_color(@satisfaction)}"}
            >
              {gettext("Satisfaction")} {@satisfaction}%
            </span>
          </h3>

          <.squad_resources squad={@squad} loot_types={@squad.loot_types} />
          <.squad_attack_mode squad={@squad} />
          <.squad_members members={@squad.members} />

          <div class="modal-action">
            <label phx-click="close_squad_menu" for="squad_menu" class="btn">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def squad_resources(assigns) do
    ~H"""
    <div class="bg-base-200 p-4 shadow-md text-md">
      <h4 class="text-md font-bold pb-3">{gettext("Resources")}</h4>

      <ul class="list-disc list-inside space-y-2 mt-2 text-sm">
        <.squad_resource
          name={gettext("Supplies")}
          resource_type={:supplies}
          value={@squad.resources.supplies}
          squad={@squad}
          description={gettext("Amount of supplies. Consumed when healing squad members.")}
        />
        <.squad_resource
          name={gettext("Ammo")}
          resource_type={:ammo}
          value={@squad.resources.ammo}
          squad={@squad}
          description={gettext("Ammo capacity. Consumed by squad members when firing. Obtained from ammo and weapons.")}
        />
        <.squad_resource
          name={gettext("General needs")}
          resource_type={:other}
          value={@squad.resources.other}
          squad={@squad}
          description={
            gettext(
              "Amount of resources for general needs. Periodically spent on squad needs. Obtained from all types of loot except weapons, ammo, and supplies."
            )
          }
        />
      </ul>
    </div>

    <div class="bg-base-200 p-4 shadow-md text-md mt-2">
      <h4 class="text-md font-bold pb-3">
        {gettext("Allow the squad to collect following types of loot")}
        <button
          id="squad_loot_info"
          phx-hook="Tooltip"
          data-tooltip={squad_loot_type_info()}
          class="btn btn-circle btn-xs btn-outline"
        >
          ?
        </button>
      </h4>

      <div class="flex flex-wrap gap-2">
        <%= for {item_type, item_type_name} <- Loot.allowed_item_types() do %>
          <label class={"btn btn-sm gap-2 #{if item_type in @loot_types, do: "text-primary"}"}>
            <input
              type="checkbox"
              name="loot_types"
              value={item_type}
              checked={item_type in @loot_types}
              phx-click="toggle_squad_loot_type"
              phx-value-type={item_type}
              class="hidden"
            />
            <span>{item_type_name}</span>
          </label>
        <% end %>
      </div>
    </div>
    """
  end

  def squad_attack_mode(assigns) do
    ~H"""
    <div class="bg-base-200 p-4 shadow-md text-md mt-2">
      <h4 class="text-md font-bold pb-3">
        {gettext("Attack mode")}
        <button
          id="squad_attack_mode_info"
          phx-hook="Tooltip"
          data-tooltip={gettext("Squad members will attack those you have chosen.")}
          class="btn btn-circle btn-xs btn-outline"
        >
          ?
        </button>
      </h4>
      <form phx-change="set_squad_attack_mode">
        <.input
          type="select"
          name="squad_attack_mode"
          id="squad_attack_mode"
          value={@squad.attack_mode}
          options={squad_attack_modes()}
        />
      </form>
    </div>
    """
  end

  def squad_resource(assigns) do
    assigns = assign(assigns, satisfaction: Squad.resource_satisfaction(assigns.squad, assigns.resource_type))

    ~H"""
    <li id={"squad_resource_#{@resource_type}"} phx-hook="Tooltip" data-tooltip={@description}>
      <span class="font-bold text-primary">{@name}:</span>
      <span style={"color: #{squad_satisfaction_color(@satisfaction)}"}>{@value} ({@satisfaction}%)</span>
    </li>
    """
  end

  def squad_members(assigns) do
    ~H"""
    <div class="bg-base-200 p-4 shadow-md text-md mt-2">
      <h4 class="text-md font-bold pb-3">{gettext("Members")}</h4>

      <%= if Enum.empty?(@members) do %>
        <span class="text-secondary">
          {gettext("There's no one in your squad. Look for survivors and invite them to join.")}
        </span>
      <% else %>
        <ul class="list-inside space-y-2 mt-2 text-sm">
          <%= for {uuid, member} <- @members do %>
            <li class="bg-base-100 p-3">
              <span id={"squad_member_#{uuid}_name"} phx-hook="Tooltip" data-tooltip={npc_tooltip(member.npc)}>
                {member.npc.character.name}
              </span>
              <span class="text-secondary text-xs">{gettext("Health")} {member.npc.health}</span>

              <span
                id={"squad_member_#{uuid}_profession"}
                phx-hook="Tooltip"
                data-tooltip={profession_tooltip(member.npc.character.profession)}
                class="badge badge-primary badge-sm"
              >
                {Character.readable_profession(member.npc.character)}
              </span>

              <div class="dropdown dropdown-top" id={"squad_member_#{uuid}-dropdown"} phx-hook="Dropdown">
                <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">
                  {gettext("actions")}
                </div>
                <ul tabindex="-1" class="dropdown-content menu bg-neutral z-1 w-52 p-2 shadow-sm">
                  <li
                    phx-click="fire_squad_member"
                    phx-value-uuid={"#{uuid}"}
                    data-confirm={gettext("Are you sure you want to kick this member from the squad?")}
                    {dropdown_attrs()}
                  >
                    <a>{gettext("Fire")}</a>
                  </li>
                </ul>
              </div>
              <div class="text-xs text-white/40 mt-1">
                {squad_member_job(member.npc)}
              </div>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  def squad_event(assigns) do
    ~H"""
    <%= if @squad_event do %>
      <input type="checkbox" id="squad_event" class="modal-toggle" checked={true} phx-change="close_squad_event" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh] max-w-2xl bg-base-200">
          <h3 class="text-lg font-bold pb-3">
            {gettext("Squad event")}
          </h3>

          <.squad_event_message squad_event={@squad_event} />

          <div class="modal-action">
            <label phx-click="close_squad_event" for="squad_event" class="btn btn-accent">{gettext("Close")}</label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def squad_event_message(assigns) do
    case assigns.squad_event do
      {:recruited, %Squad.Member{npc: npc}} ->
        assigns = assign(assigns, npc: npc)

        ~H"""
        <div>
          <span id="recruited_npc" phx-hook="Tooltip" data-tooltip={npc_tooltip(@npc)} class="text-md text-primary">
            {@npc.character.name}
          </span>
          <span class="text-secondary">{gettext("joined your squad")}!</span>
        </div>
        """

      {:declined, %Npc{} = npc} ->
        assigns = assign(assigns, npc: npc)

        ~H"""
        <div>
          <span id="declined_npc" phx-hook="Tooltip" data-tooltip={npc_tooltip(@npc)} class="text-md text-primary">
            {@npc.character.name}
          </span>
          <span class="text-red-500">
            {gettext("rejected your offer because your squad is not developed enough.")}
          </span>
        </div>

        <div class="text-sm mt-3">
          {gettext(
            "You'll be able to invite again after some time. In the meantime, focus on gathering resources for your squad."
          )}
        </div>
        """

      {:member_died, %Squad.Member{npc: npc, coord: coord}} ->
        assigns = assign(assigns, npc: npc, coord: coord)

        ~H"""
        <div>
          <span id="died_npc" phx-hook="Tooltip" data-tooltip={npc_tooltip(@npc)} class="text-md text-primary">
            {@npc.character.name}
          </span>
          <span class="text-red-500">{gettext("died at")} {coord(@coord)}</span>
        </div>
        """

      {:member_left_squad, %Squad.Member{npc: npc}} ->
        assigns = assign(assigns, npc: npc)

        ~H"""
        <div>
          <span id="left_npc" phx-hook="Tooltip" data-tooltip={npc_tooltip(@npc)} class="text-md text-primary">
            {@npc.character.name}
          </span>
          <span class="text-red-500">{gettext("has left the squad")}.</span>
        </div>

        <div class="text-sm mt-3">{gettext("Monitor the squad's resources to ensure members remain in the squad.")}</div>
        """

      :low_resources ->
        ~H"""
        <div class="text-md text-red-500">
          {gettext(
            "The level of important resources has dropped to a critical level; if you don't replenish them, people will start leaving the squad."
          )}
        </div>
        """
    end
  end

  def mascot_image(assigns) do
    image =
      Enum.random([
        ~p"/images/mascots/smoking.gif",
        ~p"/images/mascots/badminton.gif",
        ~p"/images/mascots/imposter.gif"
      ])

    assigns = assign(assigns, image: image)

    ~H"""
    <img src={@image} />
    """
  end

  ### Helpers ###

  defp coord({x, y}), do: "#{x};#{y}"

  defp interaction_tool_name(%Tool{stackable?: true} = tool) do
    Loot.Item.composed_name(tool)
  end

  defp interaction_tool_name(%Tool{name: name}), do: name

  defp craft_item_name(%Loot.Weapon{name: name}), do: name
  defp craft_item_name(%Loot.Weapon.Ammo{caliber: caliber}), do: "AMMO: #{caliber}"
  defp craft_item_name(%Loot.Resource{} = resource), do: resource.name
  defp craft_item_name(%Loot.Tool{} = tool), do: tool.name
  defp craft_item_name(%Loot.Supply{} = supply), do: supply.name

  defp craft_resources_requirements(resources, %Player{} = player) when is_list(resources) do
    resources
    |> Enum.map(fn required_resource ->
      player_resources_count = PlayerManager.resources_amount(player, required_resource)
      count = "#{player_resources_count}/#{required_resource.count}"
      count_class = required_resource_class(player_resources_count, required_resource)

      {craft_item_name(required_resource), count, count_class}
    end)
    |> to_ul()
  end

  defp required_resource_class(%Player{} = player, required_resource) do
    player
    |> PlayerManager.resources_amount(required_resource)
    |> required_resource_class(required_resource)
  end

  defp required_resource_class(player_resources_count, required_resource) do
    if player_resources_count >= required_resource.count do
      "text-blue-500"
    else
      "text-red-500"
    end
  end

  defp required_tool_class(%Player{} = player, required_tool) do
    player
    |> PlayerManager.tools_amount(required_tool)
    |> required_tool_class(required_tool)
  end

  defp required_tool_class(player_tools_count, required_tool) do
    if player_tools_count >= required_tool.count do
      "text-blue-500"
    else
      "text-red-500"
    end
  end

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

  defp get_item_attrs(item, nil, player) do
    item
    |> Item.readable_attrs(player)
    |> Enum.map(fn {_attr, name, value} -> {name, value} end)
  end

  defp get_item_attrs(item, current_item, player) do
    item_attrs = Item.readable_attrs(item, player)
    current_item_attrs = Item.readable_attrs(current_item, player)

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

  defp disease_tooltip(disease) do
    debuffs =
      disease
      |> Disease.readable_debuffs()
      |> Enum.map(fn {_, name, value} -> {name, value} end)
      |> to_ul()

    description =
      gettext("In case of complete dissatisfaction with the disease, you will receive the following effects") <> ":"

    [description(description), debuffs]
  end

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

    attrs =
      item
      |> get_item_attrs(current_item, player)
      |> to_ul()

    [item_description(item) | attrs]
  end

  defp craft_item_tooltip(item, required_tools, player) do
    requirements =
      ~s|<span class="font-semibold pb-10">| <>
        gettext("Required items") <> ~s|:</span>| <> craft_resources_requirements(required_tools, player)

    [item_description(item) | requirements]
  end

  defp npc_tooltip(%Npc{} = npc) do
    npc
    |> Npc.readable_stats()
    |> to_ul()
  end

  defp profession_tooltip(profession) do
    profession = Map.fetch!(@professions, profession)

    properties =
      Enum.map(profession.properties, fn %Profession.Property{id: property_id, level: level} ->
        {Profession.Property.property_description(property_id), "#{gettext("level")} #{level}"}
      end)

    description =
      if Enum.empty?(properties) do
        gettext("Does not have any special skills.")
      else
        gettext("Possesses skills that are useful to the squad") <> ":"
      end

    [description(description), to_ul(properties)]
  end

  defp enemy_tooltip(%Enemy{stand_on: tile}) when tile in @swimable_tiles do
    gettext("Something under water")
  end

  defp enemy_tooltip(%Enemy{} = enemy) do
    stats =
      enemy
      |> Enemy.readable_stats()
      |> to_ul()

    [enemy_description(enemy) | stats]
  end

  defp stat_tooltip(:health) do
    description = gettext("Your health indicator.")
    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:accuracy) do
    description =
      gettext(
        "Your accuracy rating. The higher the value, the greater your chance of hitting your target. This rating increases while aiming."
      )

    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:efficiency) do
    description =
      gettext(
        "Your efficiency indicator. The higher the value, the greater the chance your action will take one turn less."
      )

    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:inventory) do
    description =
      gettext(
        "Your inventory load in kilograms. If slightly overloaded, your actions will take more turns; if heavily overloaded, you won't be able to move."
      )

    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:warm) do
    description =
      gettext(
        "Your warmth level. If it drops to zero, you'll start dying from frostbite. The warmer you are, the slower you'll freeze."
      )

    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:thirst) do
    description =
      gettext(
        "Your thirst level. The higher the value, the more thirsty you become. When you reach a critical point, you'll begin to die of thirst."
      )

    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:hunger) do
    description =
      gettext(
        "Your hunger level. The higher the value, the more you want to eat. When it reaches a critical point, you'll begin to starve to death."
      )

    description(description, _with_breaks? = false)
  end

  defp stat_tooltip(:radiation) do
    description =
      gettext(
        "Your radiation contamination level. The higher the value, the more contaminated you are and the greater the risk of damage from accumulated radiation."
      )

    description(description, _with_breaks? = false)
  end

  defp tile_tooltip(tile, player) do
    case tile do
      @player ->
        player
        |> PlayerManager.readable_stats()
        |> to_ul()

      %Enemy{} = enemy ->
        enemy_tooltip(enemy)

      %Npc{} = npc ->
        npc_tooltip(npc)

      # this is for "skip" object, see Objects module
      %Object{name: "", image_name: "", stand_on: tile} ->
        tile_tooltip(tile, player)

      {:storm, _} ->
        gettext("Storm")

      tile ->
        Planet.readable_tile_name(tile)
    end
  end

  defp item_description(item) do
    item
    |> Loot.Item.description()
    |> description()
  end

  defp enemy_description(%Enemy{description: description}) do
    description(description)
  end

  defp description(text, with_breaks? \\ true) do
    description = ~s|<span class="italic text-base-content">| <> text <> ~s|</span>|

    if with_breaks? do
      description <> "<br /></br />"
    else
      description
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

  defp get_image_name({:storm, direction}, _) do
    "storm_#{direction}.gif"
  end

  defp get_image_name(:player, %Player{stand_on: stand_on} = player) when stand_on in @lethal_tiles do
    get_image_name(stand_on, player)
  end

  defp get_image_name(:player, %Player{view_direction: view_direction, stand_on: stand_on} = player) do
    cond do
      PlayerManager.stand_on_lethal_tile?(player) ->
        recursive_get_image_name(stand_on, player)

      player.health == 0 ->
        "player_dead_#{landscape_name(stand_on)}.gif"

      true ->
        view_direction = Atom.to_string(view_direction)

        "player#{aiming_player_image_prefix(player)}_#{view_direction}_#{landscape_name(stand_on)}" <>
          ext_by_stand_on(stand_on)
    end
  end

  defp get_image_name(%ItemBox{items: [], stand_on: stand_on, empty_image_name: image_name, gif_tile?: true}, _)
       when not is_nil(image_name) do
    "#{image_name}_#{landscape_name(stand_on)}.gif"
  end

  defp get_image_name(%ItemBox{items: [], stand_on: stand_on, empty_image_name: image_name}, _)
       when not is_nil(image_name) do
    "#{image_name}_#{landscape_name(stand_on)}" <> ext_by_stand_on(stand_on)
  end

  defp get_image_name(%ItemBox{stand_on: stand_on, image_name: image_name, gif_tile?: true}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.gif"
  end

  defp get_image_name(%ItemBox{stand_on: stand_on, image_name: image_name}, _) do
    "#{image_name}_#{landscape_name(stand_on)}" <> ext_by_stand_on(stand_on)
  end

  defp get_image_name(%Enemy{stand_on: tile}, _) when tile in @swimable_tiles do
    "water_with_monster.gif"
  end

  defp get_image_name(%Enemy{image_name: image_name, stand_on: stand_on, gif_tile?: true}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.gif"
  end

  defp get_image_name(%Enemy{image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}" <> ext_by_stand_on(stand_on)
  end

  defp get_image_name(%Npc{stand_on: stand_on, view_direction: view_direction} = npc, _) do
    "player#{aiming_npc_image_prefix(npc)}_#{view_direction}_#{landscape_name(stand_on)}" <> ext_by_stand_on(stand_on)
  end

  # this is for "skip" object, see Objects module
  defp get_image_name(%Object{name: "", image_name: "", stand_on: tile}, player) do
    get_image_name(tile, player)
  end

  defp get_image_name(%Object{gif_tile?: true, image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.gif"
  end

  defp get_image_name(%Object{image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}" <> ext_by_stand_on(stand_on)
  end

  defp get_image_name(tile, _) do
    landscape_name(tile) <> ext_by_stand_on(tile)
  end

  defp recursive_get_image_name(%{stand_on: tile}, player), do: recursive_get_image_name(tile, player)
  defp recursive_get_image_name(tile, player), do: get_image_name(tile, player)

  # this is for "skip" object, see Objects module
  defp landscape_name(%Object{name: "", image_name: "", stand_on: tile}) do
    landscape_name(tile)
  end

  defp landscape_name(%Object{movable?: true, image_name: image_name, stand_on: stand_on}),
    do: "#{image_name}_#{landscape_name(stand_on)}"

  defp landscape_name(%ItemBox{items: [], empty_image_name: image_name, stand_on: stand_on})
       when not is_nil(image_name) do
    "#{image_name}_#{landscape_name(stand_on)}"
  end

  defp landscape_name(%ItemBox{image_name: image_name, stand_on: stand_on}) do
    "#{image_name}_#{landscape_name(stand_on)}"
  end

  defp landscape_name(tile) do
    Map.get(@tiles_image_names, tile)
  end

  defp aiming_player_image_prefix(%Player{aim_mode?: true}), do: "_aiming"
  defp aiming_player_image_prefix(_), do: ""

  defp aiming_npc_image_prefix(%Npc{target: target}) when is_binary(target) or target == :player, do: "_aiming"
  defp aiming_npc_image_prefix(_), do: ""

  defp ext_by_stand_on(%{stand_on: stand_on}), do: ext_by_stand_on(stand_on)

  defp ext_by_stand_on(stand_on) do
    if stand_on in @gif_tiles do
      ".gif"
    else
      ".png"
    end
  end

  defp get_player_weapon(player) do
    case PlayerManager.get_equipped_weapon(player) do
      {:ok, weapon} -> weapon
      _ -> nil
    end
  end

  defp get_player_melee_weapon(player) do
    case PlayerManager.get_equipped_melee_weapon(player) do
      {:ok, melee_weapon} -> melee_weapon
      _ -> nil
    end
  end

  defp get_player_helmet(player) do
    case PlayerManager.get_equipped_helmet(player) do
      {:ok, helmet} -> helmet
      _ -> nil
    end
  end

  defp get_player_suit(player) do
    case PlayerManager.get_equipped_suit(player) do
      {:ok, suit} -> suit
      _ -> nil
    end
  end

  defp get_player_boots(player) do
    case PlayerManager.get_equipped_boots(player) do
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
      control_hint(gettext("Aim mode"), @aim_keys),
      control_hint(gettext("Zoom mode"), @zoom_keys),
      control_hint(gettext("Map"), @map_keys),
      control_hint(gettext("Squad menu"), @squad_keys),
      control_hint(gettext("Compass"), @compass_keys),
      control_hint(gettext("Skip turn"), @skip_turn_keys),
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

  defp add_compass_target_attrs do
    ["phx-click": add_compass_target_click()]
  end

  defp dropdown_attrs do
    [onclick: "document.activeElement.blur()"]
  end

  defp open_inventory_click do
    JS.dispatch("js:play-sound", detail: %{name: "click"}) |> JS.push("open_inventory")
  end

  defp add_compass_target_click do
    JS.dispatch("js:play-sound", detail: %{name: "click"}) |> JS.push("open_compass_target_menu")
  end

  defp open_craft_menu_attrs(type \\ nil) do
    attrs = ["phx-click": open_craft_menu_click()]

    if type do
      attrs ++ ["phx-value-type": type]
    else
      attrs
    end
  end

  defp open_craft_menu_click do
    JS.dispatch("js:play-sound", detail: %{name: "click"}) |> JS.push("open_craft_menu")
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

  defp maybe_round_number(number) when is_float(number) do
    NumberHelpers.round(number, 2)
  end

  defp maybe_round_number(number) do
    number
  end

  defp interaction_allowed?({:required_tools, requirements}, player) when is_list(requirements) do
    PlayerManager.enough_tools?(player, requirements)
  end

  defp interaction_allowed?({:pick_transform, _}, _), do: false

  defp interaction_allowed?(_, _), do: true

  defp tile_image_size(false = _zoom_mode), do: "30px"
  defp tile_image_size(_), do: "64px"

  defp zoom_visible_planet(visible_planet, size) do
    rows = length(visible_planet)
    cols = length(hd(visible_planet))

    start_row = div(rows - size, 2)
    start_col = div(cols - size, 2)

    visible_planet
    |> Enum.slice(start_row, size)
    |> Enum.map(fn row -> Enum.slice(row, start_col, size) end)
  end

  defp coords_distance({x1, y1}, {x2, y2}) do
    distance = abs(x1 - x2) + abs(y1 - y2)
    "#{distance} " <> gettext("meter(s)")
  end

  defp coords_angle({x1, y1}, {x2, y2}) do
    dx = x2 - x1
    dy = y2 - y1

    rad = :math.atan2(dy, dx)

    deg = rad * 180 / :math.pi()
    deg + 90
  end

  defp tile_uid(:player), do: "player"
  defp tile_uid(%{uuid: uuid}), do: "#{uuid}"
  defp tile_uid(_), do: ""

  defp age_at_disaster(age) when age > 0 do
    age
  end

  defp age_at_disaster(_), do: gettext("Not yet born")

  defp npc_color_filter(%Npc{} = npc, squad) do
    cond do
      Squad.member?(squad, npc) ->
        "filter: sepia(0.6) hue-rotate(185deg) saturate(1.8) brightness(0.9);"

      npc.target == :player || npc.player_enemy? ->
        "filter: sepia(0.6) hue-rotate(330deg) saturate(1.8) brightness(0.9);"

      true ->
        ""
    end
  end

  defp npc_color_filter(_, _), do: ""

  defp item_image_path(item) do
    category =
      case Loot.Item.item_type(item) do
        :weapon -> "weapons"
        :melee_weapon -> "melee_weapons"
        :helmet -> "helmets"
        :suit -> "suits"
        :boots -> "boots"
      end

    "/images/equipment/#{category}/#{item.image_name <> ".png"}"
  end

  defp build_map_data(map) do
    map
    |> Enum.map(fn row ->
      Enum.map(row, fn tile ->
        char = map_tile_char(tile)

        %{
          color: map_color(tile),
          text_color: map_text_color(tile),
          char: char
        }
      end)
    end)
    |> Jason.encode!()
  end

  defp map_tile_char(:player), do: "@"
  defp map_tile_char(%Npc{}), do: "N"
  defp map_tile_char(%Enemy{}), do: "E"
  defp map_tile_char(_), do: nil

  defp map_color(%{map_color: color}), do: color

  defp map_color(%{stand_on: tile}), do: map_color(tile)

  defp map_color(tile) do
    tile = Tiles.tile_by_atom_value(tile) || Tiles.tile_by_blood_version(tile)

    if tile do
      tile.map_color
    else
      "#000000"
    end
  end

  defp map_text_color(:player), do: "#55cc1e"
  defp map_text_color(%Npc{}), do: "#042a88"
  defp map_text_color(%Enemy{}), do: "#a30404"
  defp map_text_color(_), do: "#ffffff"

  defp use_item_icon_image(%Tool{using_type: :switch, active?: false}) do
    "done"
  end

  defp use_item_icon_image(%Tool{using_type: :switch, active?: true}) do
    "cross"
  end

  defp use_item_icon_image(_) do
    "tool"
  end

  defp disassemble_item_name(item, count) when count > 1 do
    item
    |> struct!(count: item.count * count)
    |> Loot.Item.composed_name()
  end

  defp disassemble_item_name(item, _), do: Loot.Item.composed_name(item)

  defp diseases_info([_ | _] = diseases) do
    count = Enum.count(diseases)
    disease = Enum.min_by(diseases, fn disease -> disease.satisfaction end)
    text = disease_state(disease.satisfaction)
    color = disease_color(disease.satisfaction)

    {gettext("Diseases") <> ": #{text} (#{count})", color}
  end

  defp diseases_info(_), do: {gettext("No diseases"), "#99c627"}

  defp disease_state(satisfaction) do
    cond do
      satisfaction == 0 -> gettext("exacerbation")
      satisfaction < 20 -> gettext("critical condition")
      satisfaction < 70 -> gettext("discomfort")
      true -> gettext("normal")
    end
  end

  defp disease_color(satisfaction) do
    cond do
      satisfaction == 0 -> "#991212"
      satisfaction < 20 -> "#d81515"
      satisfaction < 70 -> "#d24f17"
      true -> "#5e8e2c"
    end
  end

  defp squad_satisfaction_color(satisfaction) when is_integer(satisfaction) do
    cond do
      satisfaction >= 100 -> "#4a57e9"
      satisfaction >= 70 -> "#5ac421"
      satisfaction >= 50 -> "#d85627"
      true -> "#de0b0b"
    end
  end

  defp squad_attack_modes do
    Squad.attack_modes()
    |> Enum.map(fn {value, name} ->
      {name, value}
    end)
  end

  defp squad_loot_type_info do
    [
      gettext(
        "Squad members will automatically collect items of the selected types and replenish the squad's resources. Click on the desired type to allow or prohibit its collection."
      ),
      "<br /><br />",
      gettext(
        "Alternatively, you can collect all the loot yourself and give the squad the necessary items from your inventory."
      )
    ]
    |> Enum.join("\n")
  end

  defp squad_member_job(%Npc{target: {_x, _y}}), do: gettext("Gathering supplies")
  defp squad_member_job(%Npc{target: uuid}) when is_binary(uuid), do: gettext("Fighting")
  defp squad_member_job(%Npc{}), do: gettext("Follows you")

  defp start_screen_tip do
    texts = [
      gettext("Don't be upset when you die, it happens to everyone."),
      gettext("Don't forget to monitor your health indicators!"),
      gettext("Some Europeans are not as simple as they seem."),
      gettext("At night, you may unexpectedly run into enemies at an unsafe distance. Better find a flashlight!"),
      gettext("Will you survive alone or try to find companions?"),
      gettext("Moving against the storm takes more turns."),
      gettext("In aiming mode, shooting accuracy increases, but the shot takes more turns."),
      gettext("Cities are full of supplies, which is equally tempting for survivors and monsters."),
      gettext("If you walk on thin ice, you're walking on thin ice. No cracks about it!"),
      gettext("They say that if you take off your spacesuit, you will leave Europa faster."),
      gettext("Got into trouble? Just don't press any buttons and everything will be fine!"),
      gettext(
        "Sometimes it's useful to skip a turn and wait for the situation to resolve itself without your participation."
      ),
      gettext("Good luck.")
    ]

    Enum.random(texts)
  end

  # coveralls-ignore-stop
end
