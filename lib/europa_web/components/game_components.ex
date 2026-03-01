defmodule EuropaWeb.GameCompotents do
  # coveralls-ignore-start
  use EuropaWeb, :html
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Loot
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Loot.Item
  alias Europa.Server.Chat

  import Europa.Tools.Conf

  @player Planet.player()
  @snow Planet.snow()
  @snow_blood Planet.snow_blood()
  @ice Planet.ice()
  @ice_blood Planet.ice_blood()
  @path Planet.path()
  @path_blood Planet.path_blood()
  @water Planet.water()

  @move_up_keys fetch_config!([:control_bindings, :move_up])
  @move_down_keys fetch_config!([:control_bindings, :move_down])
  @move_left_keys fetch_config!([:control_bindings, :move_left])
  @move_right_keys fetch_config!([:control_bindings, :move_right])

  @loot_keys fetch_config!([:control_bindings, :loot])
  @inventory_keys fetch_config!([:control_bindings, :inventory])
  @reload_keys fetch_config!([:control_bindings, :reload])
  @control_hints_keys fetch_config!([:control_bindings, :control_hints])
  @close_keys fetch_config!([:control_bindings, :close])
  @shoot_keys fetch_config!([:control_bindings, :shoot])

  def start_screen(assigns) do
    ~H"""
    <div class="w-full p-5 m-5 rounded-box shadow-md grid place-items-center">
      <button id="start_buttom" phx-click="start_game" class="btn btn-xl btn-success">{gettext("Start game")}</button>
    </div>
    """
  end

  def game_field(assigns) do
    ~H"""
    <div class="w-3/6 h-fit bg-base-200 p-5 m-5 rounded-box shadow-md grid place-items-center">
      <%= for {row, x} <- Enum.with_index(@visible_planet) do %>
        <div class="flex gap-0">
          <%= for {tile, y} <- Enum.with_index(row) do %>
            <img
              id={"tile_#{x}_#{y}"}
              phx-hook="Tooltip"
              data-tooltip={tile_tooltip(tile, @player)}
              src={~p"/images/#{render_tile(tile, @player)}"}
              height="30"
              width="30"
            />
          <% end %>
        </div>
      <% end %>
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

  def player_stats(assigns) do
    ~H"""
    <div class="bg-base-200 p-5 rounded-box shadow-md text-lg">
      <ul class="flex space-x-4">
        <li>
          <div class="tooltip" data-tip={gettext("Health")}>
            💙 {@player_stats.health}
          </div>
        </li>
        <li {open_inventory_attrs()}>
          <div class="tooltip" data-tip={gettext("Inventory")}>
            💼 {@player_stats.inventory}
          </div>
        </li>
        <li>
          <div class="tooltip" data-tip={gettext("Accuracy")}>
            🎯 {@player_stats.accuracy}
          </div>
        </li>
        <li>
          <div class="tooltip" data-tip={gettext("Efficiency")}>
            🦌 {@player_stats.efficiency}
          </div>
        </li>
      </ul>
    </div>
    """
  end

  def control_hints_link(assigns) do
    ~H"""
    <div class="bg-base-200 p-5 rounded-box shadow-md text-xs">
      <.link phx-click="show_control_hints">{gettext("Control hints")}</.link>
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
        <div class="modal-box overflow-visible overflow-y-auto">
          <h3 class="text-lg font-bold">{gettext("Inventory")} ({@player_stats.inventory})</h3>
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
                    <%= if weapon?(item) do %>
                      <div class="dropdown">
                        <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1">actions</div>
                        <ul tabindex="-1" class="dropdown-content menu bg-neutral rounded-box z-1 w-52 p-2 shadow-sm">
                          <li phx-click="unload_weapon" phx-value-uuid={"#{item.uuid}"}><a>{gettext("Unload")}</a></li>
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
        <div class="modal-box overflow-visible overflow-y-auto mt-[5vh]">
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
                    <%= if weapon?(item) do %>
                      <div class="dropdown">
                        <div tabindex="0" role="button" class="btn btn-xs btn-dash m-1">actions</div>
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
    Item.readable_attrs(item)
  end

  defp get_item_attrs(item, current_item) do
    item_attrs = Item.readable_attrs(item)
    current_item_attrs = Item.readable_attrs(current_item)

    Enum.with_index(item_attrs, fn {name, value}, index ->
      {_current_name, current_value} = Enum.at(current_item_attrs, index)

      cond do
        (is_binary(value) or is_atom(value)) && value != current_value ->
          {name, "#{value} (diff)"}

        is_integer(value) && value > current_value ->
          {name, "#{value} (+#{value - current_value})", "text-blue-500"}

        is_integer(value) && value < current_value ->
          {name, "#{value} (-#{current_value - value})", "text-red-500"}

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

      @snow ->
        gettext("Snow")

      @snow_blood ->
        gettext("Bloody snow")

      @ice ->
        gettext("Ice")

      @ice_blood ->
        gettext("Ice blood")

      @path ->
        gettext("Path")

      @path_blood ->
        gettext("Bloody path")

      @water ->
        gettext("Water")

      %ItemBox{} = item_box ->
        ItemBox.readable_name(item_box)

      _ ->
        "..."
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

  defp get_image_name(@water, _) do
    "water.gif"
  end

  defp get_image_name(%ItemBox{type: :monster_body, stand_on: stand_on}, _) do
    "monster_corpse_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{type: :crashed_shuttle, stand_on: stand_on}, _) do
    "crashed_shuttle_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%ItemBox{stand_on: stand_on}, _) do
    "factory_box_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(%Enemy{image_name: image_name, stand_on: stand_on}, _) do
    "#{image_name}_#{landscape_name(stand_on)}.png"
  end

  defp get_image_name(tile, _) do
    landscape_name(tile) <> ".png"
  end

  defp landscape_name(@snow), do: "snow"
  defp landscape_name(@ice), do: "ice"
  defp landscape_name(@path), do: "path"
  defp landscape_name(@snow_blood), do: "blood_snow"
  defp landscape_name(@ice_blood), do: "blood_ice"
  defp landscape_name(@path_blood), do: "blood_path"

  defp landscape_name(%ItemBox{type: :monster_body, stand_on: stand_on}),
    do: "monster_corpse_#{landscape_name(stand_on)}"

  defp get_player_weapon(player) do
    case Player.get_equiped_weapon(player) do
      {:ok, weapon} -> weapon
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
      control_hint(gettext("Move up"), @move_up_keys),
      control_hint(gettext("Move down"), @move_down_keys),
      control_hint(gettext("Move left"), @move_left_keys),
      control_hint(gettext("Move right"), @move_right_keys),
      control_hint(gettext("Reload weapon"), @reload_keys),
      control_hint(gettext("Loot"), @loot_keys),
      control_hint(gettext("Inventory"), @inventory_keys),
      control_hint(gettext("Control hints"), @control_hints_keys),
      control_hint(gettext("Shoot"), @shoot_keys),
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

  # coveralls-ignore-stop
end
