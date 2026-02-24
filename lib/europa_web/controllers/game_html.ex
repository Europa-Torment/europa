defmodule EuropaWeb.GameHTML do
  use EuropaWeb, :html

  alias Europa.Server.Planet
  alias Europa.Server.Player
  alias Europa.Server.Enemy
  alias Europa.Server.Loot.ItemBox
  alias Europa.Server.Loot.Item
  alias Europa.Server.Chat

  @player Planet.player()

  @snow Planet.snow()
  @snow_blood Planet.snow_blood()

  @ice Planet.ice()
  @ice_blood Planet.ice_blood()

  @path Planet.path()
  @path_blood Planet.path_blood()

  @water Planet.water()

  embed_templates("game_html/*")

  @spec chat_color(Chat.Message.t()) :: String.t()
  def chat_color(%Chat.Message{category: category}) do
    case category do
      :story -> "text-info"
      :regular -> "text-primary"
      :warning -> "text-warning"
      :danger -> "text-error"
    end
  end

  @spec render_tile(Planet.tile(), Player.t()) :: String.t()
  def render_tile(tile, player) do
    get_image_name(tile, player)
  end

  @spec render_item_box_name(ItemBox.t()) :: String.t()
  def render_item_box_name(%ItemBox{} = item_box) do
    ItemBox.readable_name(item_box)
  end

  @spec render_item_name(Item.item()) :: String.t()
  def render_item_name(item) do
    Item.composed_name(item)
  end

  @spec get_item_attrs(Item.item(), Item.item() | nil) :: list()
  def get_item_attrs(item, nil) do
    Item.readable_attrs(item)
  end

  def get_item_attrs(item, current_item) do
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

  @spec item_equipable?(Item.item()) :: boolean()
  def item_equipable?(item) do
    Item.equipable?(item)
  end

  @spec item_tooltip(Item.item(), Player.t()) :: String.t()
  def item_tooltip(item, player) do
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

  @spec tile_tooltip(Planet.tile(), Player.t()) :: String.t()
  def tile_tooltip(tile, player) do
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
        render_item_box_name(item_box)

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
end
