defmodule EuropaWeb.GameCompotents do
  # coveralls-ignore-start
  use EuropaWeb, :html
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.PlayerManager
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Event
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
  @aim_keys fetch_config!([:control_bindings, :aim])

  @max_thirst fetch_config!([:game_params, :player, :max_thirst])
  @max_hunger fetch_config!([:game_params, :player, :max_hunger])

  @low_health_ratio fetch_config!([:game_params, :player, :low_health_ratio])

  @craft_moves_count fetch_config!([:game_params, :craft_moves_count])

  @tiles_image_names Tiles.image_names()

  @gif_tiles Tiles.gif_tiles()

  @base_tooltip_class "tooltip tooltip-open"
  @player_tooltip_class "tooltip tooltip-events tooltip-open tooltip-warning"
  @enemy_tooltip_class "tooltip tooltip-events tooltip-open tooltip-error"

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
    formatted_aim =
      Enum.map(assigns.aim, fn {{from_y, from_x}, {to_y, to_x}} ->
        %{from: "#tile_#{from_y}_#{from_x}", to: "#tile_#{to_y}_#{to_x}"}
      end)

    assigns = assign(assigns, aim: formatted_aim)

    ~H"""
    <div class="w-3/6 h-fit flex flex-col overflow-hidden bg-base-200 p-5 m-5 rounded-box shadow-md grid place-items-center">
      <%= for {row, x} <- Enum.with_index(@visible_planet) do %>
        <div class="flex gap-0">
          <%= for {tile, y} <- Enum.with_index(row) do %>
            <div class={speech_class(tile, @player)} data-tip={speech(tile, @player)}>
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
      id="aim-data"
      phx-hook="Aim"
      data-show_aim={"#{@player.aim_mode?}"}
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
      <.link phx-click="show_control_hints">ℹ️ {gettext("Control hints")}</.link>
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
            <.item_image item={@helmet} player={@player} />
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
            <.item_image item={@suit} player={@player} />
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
            <.item_image item={@boots} player={@player} />
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

        <div class="flex flex-col gap-y-0.5">
          <%= if @weapon do %>
            <.item_image item={@weapon} player={@player} />
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
          <%= if @melee_weapon do %>
            <.item_image item={@melee_weapon} player={@player} />
          <% else %>
            <img
              id="no-melee-weapon"
              {open_inventory_attrs("melee_weapon")}
              phx-hook="Tooltip"
              data-tooltip={gettext("No melee weapon")}
              src={~p"/images/fist.png"}
              alt="4"
              class="bg-neutral w-full h-auto object-cover rounded-sm"
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def item_image(assigns) do
    ~H"""
    <img
      id={"#{Loot.Item.item_type(@item)}-#{@item.uuid}"}
      {open_inventory_attrs("#{Loot.Item.item_type(@item)}")}
      phx-hook="Tooltip"
      data-tooltip={item_tooltip(@item, @player)}
      src={~p"/images/#{@item.image_name <> ".png"}"}
      alt="4"
      class="bg-neutral w-full h-auto object-cover rounded-sm"
    />
    """
  end

  def ammo_info(assigns) do
    ~H"""
    <%= if @weapon do %>
      <div class="bg-base-200 p-5 rounded-box shadow-md text-xs" {open_inventory_attrs("ammo")}>
        <p class="tooltip" data-tip={"#{gettext("Loaded")}/#{gettext("Magazine size")}/#{gettext("In inventory")}"}>
          🔫 {@weapon.caliber}: {@weapon.rounds_loaded}/{@weapon.magazine_size}/{@ammo_count}
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
    assigns = assign(assigns, craft_moves_count: @craft_moves_count)

    ~H"""
    <%= if @inventory do %>
      <input type="checkbox" id="inventory" class="modal-toggle h-screen" checked={true} phx-change="close_inventory" />
      <div class="modal overflow-visible" role="dialog">
        <div class="modal-box overflow-visible overflow-y-auto max-w-2xl">
          <h3 class="text-lg font-bold">
            {gettext("Inventory")} ({@player_stats.inventory_weight}/{@player_stats.max_weight}{gettext("kg")})
            <button class="btn btn-primary btn-sm" {open_craft_menu_attrs()}>
              🛠️ {gettext("Craft items")}
            </button>
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
                  <li>
                    <span
                      id={"loot_item_#{item.uuid}"}
                      phx-hook="Tooltip"
                      data-tooltip={item_tooltip(item, @player)}
                    >
                      {Item.composed_name(item)}
                    </span>
                    <.item_quick_action item={item} />
                    <div class="dropdown dropdown-top" id={"item-#{item.uuid}-dropdown"} phx-hook="Dropdown">
                      <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">actions</div>
                      <ul tabindex="-1" class="dropdown-content menu bg-neutral rounded-box z-1 w-52 p-2 shadow-sm">
                        <%= if weapon?(item) && item.rounds_loaded < item.magazine_size do %>
                          <li phx-click="reload_weapon" phx-value-uuid={"#{item.uuid}"} {dropdown_attrs()}>
                            <a>{gettext("Reload")} <.moves_count moves_count={item.reload_cost} /></a>
                          </li>
                        <% end %>
                        <%= if weapon?(item) && item.rounds_loaded > 0 do %>
                          <li phx-click="unload_weapon" phx-value-uuid={"#{item.uuid}"} {dropdown_attrs()}>
                            <a>{gettext("Unload")} <.moves_count moves_count={item.reload_cost} /></a>
                          </li>
                        <% end %>
                        <%= if Loot.Item.disassemblable?(item) do %>
                          <li phx-click="disassemble_item" phx-value-uuid={"#{item.uuid}"} {dropdown_attrs()}>
                            <a>{gettext("Disassemble")}<.moves_count moves_count={@craft_moves_count} /></a>
                          </li>
                        <% end %>
                        <li phx-click="drop_item" phx-value-uuid={"#{item.uuid}"} {dropdown_attrs()}>
                          <a>{gettext("Drop")}</a>
                        </li>
                        <%= if Loot.Item.stackable?(item) do %>
                          <li phx-click="open_item_drop_menu" phx-value-uuid={"#{item.uuid}"} {dropdown_attrs()}>
                            <a>{gettext("Drop partly")}</a>
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  </li>
                </div>
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
                        <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1 item-dropdown-button">actions</div>
                        <ul tabindex="-1" class="dropdown-content menu bg-neutral rounded-box z-1 w-52 p-2 shadow-sm">
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

          <%= if interaction_requires_tools?(@interaction_confirmation) do %>
            <.interact_required_tools interaction_confirmation={@interaction_confirmation} player={@player} />
          <% end %>

          <%= if @interaction_confirmation == :danger_action do %>
            <span class="text-md">{gettext("Commit a dangerous act?")}</span>
          <% end %>

          <div class="modal-action">
            <%= if @interaction_allowed? do %>
              <label
                phx-click="interact"
                phx-value-type="forced"
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

  def interact_required_tools(assigns) do
    {:required_tools, tools} = assigns.interaction_confirmation
    assigns = assign(assigns, tools: tools)

    ~H"""
    <span class="text-md">{gettext("The action requires following items")}:</span>
    <br />

    <ul class="list-disc list-inside space-y-2 text-sm">
      <%= for tool <- @tools do %>
        <li class={required_tool_class(@player, tool)}>
          {Loot.Item.composed_name(tool)}, {gettext("you have")}: {PlayerManager.tools_amount(@player, tool)}
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
            <button class="btn btn-secondary" phx-click="drop_item" phx-value-uuid={"#{@item_to_drop.uuid}"}>
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
          <h3 class="text-lg font-bold pb-3">{gettext("After disassembling you will receive following items:")}</h3>
          <div>
            <ul class="list-disc list-inside space-y-2 text-sm">
              <%= for item <- @disassemble_items do %>
                <li
                  id={"disassemble_item_#{item.uuid}"}
                  phx-hook="Tooltip"
                  data-tooltip={item_tooltip(item, @player)}
                >
                  {Loot.Item.composed_name(item)}
                </li>
              <% end %>
            </ul>
          </div>
          <div class="modal-action">
            <label
              phx-click="confirm_item_disassemble"
              phx-value-uuid={"#{@disassemble_item_uuid}"}
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
                <%= for %Loot.Blueprint{item: item, tools: required_tools} <- @blueprints do %>
                  <li
                    id={"craft_item_#{item.uuid}"}
                    phx-hook="Tooltip"
                    data-tooltip={craft_item_tooltip(item, required_tools, @player)}
                  >
                    {craft_item_name(item)}
                    <%= if PlayerManager.enough_tools?(@player, required_tools) do %>
                      <div class="tooltip" data-tip={"#{gettext("Create")}"}>
                        <.link phx-click="craft_item" phx-value-uuid={"#{item.uuid}"}>
                          🛠️ <.moves_count moves_count={@craft_moves_count} />
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
          💊 <.moves_count moves_count={@item.consume_cost} />
        </.link>
      </div>
    <% end %>
    <%= if Item.equipable?(@item) do %>
      <%= if @item.equiped do %>
        <div class="tooltip" data-tip={"#{gettext("Unequip")}"}>
          <.link phx-click="unequip_item" phx-value-uuid={"#{@item.uuid}"}>🫳🏻</.link>
        </div>
      <% else %>
        <div class="tooltip" data-tip={"#{gettext("Equip")}"}>
          <.link phx-click="equip_item" phx-value-uuid={"#{@item.uuid}"}>🛠️</.link>
        </div>
      <% end %>
    <% end %>
    """
  end

  def moves_count(assigns) do
    ~H"""
    <span class="italic text-base-content text-[0.625rem]">🎲{@moves_count}</span>
    """
  end

  ### Helpers ###

  defp craft_item_name(%Loot.Weapon{name: name}), do: name
  defp craft_item_name(%Loot.Tool{} = tool), do: "#{tool.name}"

  defp craft_tools_requirements(tools, %Player{} = player) when is_list(tools) do
    tools
    |> Enum.map(fn required_tool ->
      player_tools_count = PlayerManager.tools_amount(player, required_tool)
      count = "#{player_tools_count}/#{required_tool.count}"
      count_class = required_tool_class(player_tools_count, required_tool)

      {craft_item_name(required_tool), count, count_class}
    end)
    |> to_ul()
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

    attrs =
      item
      |> get_item_attrs(current_item)
      |> to_ul()

    [item_description(item) | attrs]
  end

  defp craft_item_tooltip(item, required_tools, player) do
    requirements =
      ~s|<span class="font-semibold pb-10">| <>
        gettext("Required items") <> ~s|:</span>| <> craft_tools_requirements(required_tools, player)

    [item_description(item) | requirements]
  end

  defp tile_tooltip(tile, player) do
    case tile do
      @player ->
        player
        |> PlayerManager.readable_stats()
        |> to_ul()

      %Enemy{} = enemy ->
        enemy
        |> Enemy.readable_stats()
        |> to_ul()

      %Npc{} = npc ->
        Npc.readable_stats(npc) |> to_ul()

      # this is for "skip" object, see Objects module
      %Object{name: "", image_name: "", stand_on: tile} ->
        tile_tooltip(tile, player)

      tile ->
        Planet.readable_tile_name(tile)
    end
  end

  defp item_description(item) do
    ~s|<span class="italic text-base-content">| <> Loot.Item.description(item) <> ~s|</span><br/><br/>|
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

  defp get_image_name(%ItemBox{stand_on: stand_on, image_name: image_name}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%Enemy{image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%Npc{stand_on: stand_on}, _) do
    "player_down_#{landscape_name(stand_on)}.png"
  end

  # this is for "skip" object, see Objects module
  defp get_image_name(%Object{name: "", image_name: "", stand_on: tile}, player) do
    get_image_name(tile, player)
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

  # this is for "skip" object, see Objects module
  defp landscape_name(%Object{name: "", image_name: "", stand_on: tile}) do
    landscape_name(tile)
  end

  defp landscape_name(%Object{movable?: true, image_name: image_name, stand_on: stand_on}),
    do: "#{image_name}_#{landscape_name(stand_on)}"

  defp landscape_name(%ItemBox{image_name: image_name, stand_on: stand_on}) do
    "#{image_name}_#{landscape_name(stand_on)}"
  end

  defp landscape_name(tile) do
    Map.get(@tiles_image_names, tile)
  end

  defp get_player_weapon(player) do
    case PlayerManager.get_equiped_weapon(player) do
      {:ok, weapon} -> weapon
      _ -> nil
    end
  end

  defp get_player_melee_weapon(player) do
    case PlayerManager.get_equiped_melee_weapon(player) do
      {:ok, melee_weapon} -> melee_weapon
      _ -> nil
    end
  end

  defp get_player_helmet(player) do
    case PlayerManager.get_equiped_helmet(player) do
      {:ok, helmet} -> helmet
      _ -> nil
    end
  end

  defp get_player_suit(player) do
    case PlayerManager.get_equiped_suit(player) do
      {:ok, suit} -> suit
      _ -> nil
    end
  end

  defp get_player_boots(player) do
    case PlayerManager.get_equiped_boots(player) do
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

  defp dropdown_attrs do
    [onclick: "document.activeElement.blur()"]
  end

  defp open_inventory_click do
    JS.dispatch("js:play-sound", detail: %{name: "click"}) |> JS.push("open_inventory")
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

  defp speech_class(%Npc{character: %Character{short_phrases: []}}, _player), do: ""

  defp speech_class(%Npc{}, _player) do
    if m_to_n?(1, 3) do
      @base_tooltip_class
    else
      ""
    end
  end

  defp speech_class(%Enemy{events: [_ | _]}, _player), do: @enemy_tooltip_class

  defp speech_class(:player, %Player{events: [_ | _]}) do
    @player_tooltip_class
  end

  defp speech_class(_, _), do: ""

  defp speech(%Npc{character: character}, _player) do
    Character.short_phrase(character)
  end

  defp speech(%Enemy{events: [%Event{} = event | _]}, _player) do
    event_speech(event)
  end

  defp speech(:player, %Player{events: [%Event{} = event | _]}) do
    event_speech(event)
  end

  defp speech(_, _), do: ""

  defp event_speech(%Event{type: :interested}) do
    "?"
  end

  defp event_speech(%Event{type: {:damaged, damage}}) do
    "💔 #{damage}"
  end

  defp event_speech(%Event{type: {:healed, health_change}}) do
    "💊 #{health_change}"
  end

  defp event_speech(%Event{type: {:radiation, radiation}}) do
    "☢️ #{radiation}"
  end

  defp event_speech(%Event{type: {:speech, phrase}}), do: phrase

  defp event_speech(_), do: "..."

  defp maybe_round_number(number) when is_float(number) do
    NumberHelpers.round(number, 2)
  end

  defp maybe_round_number(number) do
    number
  end

  defp interaction_requires_tools?({:required_tools, requirements}) when is_list(requirements), do: true
  defp interaction_requires_tools?(_), do: false

  defp interaction_allowed?({:required_tools, requirements}, player) when is_list(requirements) do
    PlayerManager.enough_tools?(player, requirements)
  end

  defp interaction_allowed?(_, _), do: true

  # coveralls-ignore-stop
end
