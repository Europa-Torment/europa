defmodule EuropaWeb.GameHTMLTest do
  use EuropaWeb.ConnCase, async: true

  alias EuropaWeb.GameHTML
  alias Europa.Server.Planet
  alias Europa.Server.Loot

  @s Planet.snow()
  @sb Planet.snow_blood()

  @i Planet.ice()
  @icb Planet.ice_blood()

  @p Planet.path()
  @pb Planet.path_blood()

  @w Planet.water()

  @pl Planet.player()

  @weapon build(:weapon)
  @ammo build(:ammo)

  @ib build(:loot_item_box, items: [@weapon])

  @en build(:enemy)

  describe "chat_color/1" do
    test "returns color class for chat message" do
      message = build(:chat_message)
      assert GameHTML.chat_color(message) |> is_binary()
    end
  end

  describe "render_tile/2" do
    setup do
      player = build(:player)
      {:ok, player: player}
    end

    test "returns image filename for landscape tiles", %{player: player} do
      for tile <- [@s, @sb, @i, @icb, @p, @pb, @w] do
        assert GameHTML.render_tile(tile, player) |> assert_file_ext()
      end
    end

    test "returns image filename for player tile", %{player: player} do
      assert GameHTML.render_tile(@pl, player) |> assert_file_ext()
    end

    test "returns image filename for item_box tile", %{player: player} do
      assert GameHTML.render_tile(@ib, player) |> assert_file_ext()
    end

    test "returns image filename for enemy tile", %{player: player} do
      assert GameHTML.render_tile(@en, player) |> assert_file_ext()
    end
  end

  describe "tile_tooltip/2" do
    setup do
      player = build(:player)
      {:ok, player: player}
    end

    test "returns string tooltip for tiles", %{player: player} do
      for tile <- [@s, @sb, @i, @icb, @p, @pb, @w, @pl, @en] do
        assert GameHTML.tile_tooltip(tile, player) |> is_binary()
      end
    end
  end

  describe "render_item_box_name/1" do
    test "returns item_box name" do
      assert GameHTML.render_item_box_name(@ib) == Loot.ItemBox.readable_name(@ib)
    end
  end

  describe "renders_item_name/1" do
    test "returns item name" do
      assert GameHTML.render_item_name(@weapon) == Loot.Item.composed_name(@weapon)
    end
  end

  describe "get_item_attrs/1" do
    test "returns item attrs" do
      assert GameHTML.get_item_attrs(@weapon, nil) == Loot.Item.readable_attrs(@weapon)
    end

    test "accepts all item types" do
      for item_type <- [:weapon, :ammo, :helmet, :suit, :boots] do
        item = build(item_type)
        item2 = build(item_type)

        assert GameHTML.get_item_attrs(item, item2) |> is_list()
      end
    end

    test "returns item attrs with comparsions" do
      helmet = build(:helmet, name: "name", max_health: 10, accuracy: 2)
      helmet2 = build(:helmet, name: "name 2", max_health: 20, accuracy: 1)

      assert GameHTML.get_item_attrs(helmet, helmet2) == [
               {"Name", "#{helmet.name} (diff)"},
               {"Accuracy", "#{helmet.accuracy} (+#{helmet.accuracy - helmet2.accuracy})", "text-blue-500"},
               {"Health", "#{helmet.max_health} (-#{helmet2.max_health - helmet.max_health})", "text-red-500"}
             ]
    end
  end

  describe "item_equipable?/1" do
    test "returns boolean value" do
      assert GameHTML.item_equipable?(@weapon) == true
    end
  end

  describe "weapon?/1" do
    test "returns boolean value" do
      assert GameHTML.weapon?(@weapon) == true
      assert GameHTML.weapon?(@ammo) == false
    end
  end

  describe "item_tooltip/1" do
    setup do
      player = build(:player)
      {:ok, player: player}
    end

    test "returns string", %{player: player} do
      assert GameHTML.item_tooltip(@weapon, player) |> is_binary()
    end

    test "returns string tooltip for tiles", %{player: player} do
      weapon = build(:weapon)
      ammo = build(:ammo)
      helmet = build(:helmet)
      suit = build(:suit)
      boots = build(:boots)

      equipment = [weapon, ammo, helmet, suit, boots]
      player = struct(player, inventory: equipment)

      for item <- equipment do
        assert GameHTML.item_tooltip(item, player) |> is_binary()
      end
    end
  end

  defp assert_file_ext(filename) do
    ext =
      filename
      |> String.split(".")
      |> List.last()

    assert ext in ["png", "gif"]
  end
end
