defmodule Europa.Server.Loot do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Errors.NotApplicableError
  alias Europa.Server.Planet

  alias Europa.Tools.Types
  alias Europa.Tools.AttrsDeterminator

  alias Europa.Server.Planet.Tiles

  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.MeleeWeapon
  alias Europa.Server.Loot.Helmet
  alias Europa.Server.Loot.Suit
  alias Europa.Server.Loot.Boots
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Loot.Tool
  alias Europa.Server.Loot.Resource
  alias Europa.Server.Loot.Blueprints
  alias Europa.Server.Loot.Blueprints.Blueprint
  alias Europa.Server.Loot.Implant
  alias Europa.Server.Loot.Utils.FilesReader
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Player
  alias Europa.Server.Errors

  import Europa.Tools.Randomizer

  @item_boxes_filename "item_boxes.json"

  @item_boxes FilesReader.parse_item_boxes_file(@item_boxes_filename)
  @outdoor_item_boxes Enum.filter(@item_boxes, fn {ib, _random_weight} -> String.to_atom(ib.placing) == :outdoor end)

  @allowed_item_box_types Enum.map(@item_boxes, fn {ib, _random_weight} -> String.to_atom(ib.type) end)

  @weighted_item_types [
    {:weapon, gettext("Weapons"), 0.4},
    {:ammo, gettext("Ammo"), 0.7},
    {:melee_weapon, gettext("Melee weapons"), 0.7},
    {:supply, gettext("Supplies"), 1.0},
    {:tool, gettext("Tools"), 0.5},
    {:resource, gettext("Resources"), 1.0},
    {:helmet, gettext("Helmets"), 0.4},
    {:suit, gettext("Suits"), 0.2},
    {:boots, gettext("Boots"), 0.4},
    {:implant, gettext("Implants"), 0.3}
  ]

  @item_types Enum.map(@weighted_item_types, fn {k, v, _} -> {k, v} end)

  @allowed_item_types Enum.map(@item_types, fn {k, _v} -> k end)

  @filenames %{
    weapon: "weapons.json",
    ammo: "ammo.json",
    melee_weapon: "melee_weapons.json",
    helmet: "helmets.json",
    suit: "suits.json",
    boots: "boots.json",
    supply: "supplies.json",
    tool: "tools.json",
    resource: "resources.json",
    implant: "implants.json"
  }

  @items_attrs FilesReader.parse_items_files(@filenames)

  @type item_type :: unquote(Types.one_of(@allowed_item_types))
  @type item_subtype :: atom()
  @type item_id :: atom()
  @type item_box_type :: unquote(Types.one_of(@allowed_item_box_types))

  @type attrs :: map()

  @type uuid :: Ecto.UUID.t()

  for {{item_box, _}, index} <- Enum.with_index(@item_boxes) do
    fun_name = String.to_atom("__extract_strings_for_ib_#{index}")

    def unquote(fun_name)() do
      gettext(unquote(item_box.readable_name))
    end
  end

  for {{category, items}, i} <- Enum.with_index(@items_attrs) do
    for {{item, _}, j} <- Enum.with_index(items) do
      fun_name = String.to_atom("__extract_strings_for_it_#{i}_#{j}")

      if category == :ammo do
        def unquote(fun_name)() do
          gettext(unquote(item.caliber))
          gettext(unquote(item.description))
        end
      else
        def unquote(fun_name)() do
          gettext(unquote(item.name))
          gettext(unquote(item.description))
        end
      end
    end
  end

  defprotocol Item do
    alias Europa.Server.Errors
    alias Europa.Server.Loot
    alias Europa.Server.Loot.Weapon
    alias Europa.Server.Loot.Weapon.Ammo
    alias Europa.Server.Loot.MeleeWeapon
    alias Europa.Server.Loot.Helmet
    alias Europa.Server.Loot.Suit
    alias Europa.Server.Loot.Boots
    alias Europa.Server.Loot.Supply
    alias Europa.Server.Loot.Tool

    @type item() ::
            Weapon.t()
            | Ammo.t()
            | MeleeWeapon.t()
            | Helmet.t()
            | Suit.t()
            | Boots.t()
            | Supply.t()
            | Tool.t()
            | Implant.t()
    @type weight() :: number()

    @spec item_type(item()) :: Loot.item_type()
    def item_type(item)

    @spec item_subtype(item()) :: Loot.item_subtype()
    def item_subtype(item)

    @spec id(item()) :: atom()
    def id(item)

    @spec composed_name(item()) :: String.t()
    def composed_name(item)

    @spec description(item()) :: String.t()
    def description(item)

    @spec readable_attrs(item(), Player.t()) :: list()
    def readable_attrs(item, player)

    @spec consumable?(item()) :: boolean()
    def consumable?(item)

    @spec usable?(item()) :: boolean()
    def usable?(item)

    @spec equipable?(item()) :: boolean()
    def equipable?(item)

    @spec stackable?(item()) :: boolean()
    def stackable?(item)

    @spec equip(item()) :: {:ok, item()} | {:error, Errors.NotApplicableError.t()}
    def equip(item)

    @spec unequip(item()) :: {:ok, item()} | {:error, Errors.NotApplicableError.t()}
    def unequip(item)

    @spec player_stats_changes(item()) :: map()
    def player_stats_changes(item)

    @spec negative_attrs(item()) :: list(atom())
    def negative_attrs(item)

    @spec weight(item()) :: weight()
    def weight(item)
  end

  defmodule ItemBox do
    use Gettext, backend: Europa.Gettext

    alias Europa.Server.Loot

    @allowed_placing [:outdoor, :furniture]

    @type placing :: unquote(Types.one_of(@allowed_placing))
    @type item_types :: map() | :all

    typedstruct do
      field :type, Loot.item_box_type(), enforce: true
      field :readable_name, String.t(), enforce: true
      field :item_types, item_types(), enforce: true
      field :items, list(Loot.Item.item()), enforce: true
      field :max_items, pos_integer()
      field :movable?, boolean(), enforce: true, default: false
      field :placing, placing(), enforce: true
      field :stand_on, Planet.tile()
      field :image_name, String.t()
      field :empty_image_name, String.t()
    end

    @spec from_map(map()) :: t()
    def from_map(attrs) when is_map(attrs) do
      item_types =
        case Map.fetch!(attrs, :item_types) do
          "all" ->
            :all

          types when is_map(types) ->
            parse_item_types(types)
        end

      %__MODULE__{
        type: Map.fetch!(attrs, :type) |> String.to_atom(),
        readable_name: Map.fetch!(attrs, :readable_name),
        item_types: item_types,
        items: [],
        max_items: Map.fetch!(attrs, :max_items),
        movable?: Map.fetch!(attrs, :movable),
        placing: Map.fetch!(attrs, :placing) |> String.to_atom(),
        stand_on: nil,
        image_name: Map.fetch!(attrs, :image_name),
        empty_image_name: Map.get(attrs, :empty_image_name)
      }
    end

    @spec readable_name(t()) :: String.t()
    def readable_name(%ItemBox{readable_name: readable_name}) do
      Gettext.gettext(
        Europa.Gettext,
        readable_name
      )
    end

    @spec add_item(ItemBox.t(), Item.item()) :: ItemBox.t()
    def add_item(%ItemBox{} = item_box, new_item) do
      struct!(item_box, items: [new_item | item_box.items])
    end

    @spec take_item(ItemBox.t(), Loot.uuid()) :: {:ok, Item.t(), ItemBox.t()} | {:error, :no_item}
    def take_item(%ItemBox{} = item_box, item_uuid) do
      with {:ok, item} <- find_item(item_box, item_uuid) do
        updated_items = List.delete(item_box.items, item)
        {:ok, item, struct!(item_box, items: updated_items)}
      end
    end

    @spec unload_weapon(ItemBox.t(), Loot.uuid()) ::
            {:ok, ItemBox.t(), Weapon.t()}
            | {:error, :no_item}
            | {:error, :empty_magazine}
            | {:error, Errors.NotApplicableError.t()}
    def unload_weapon(%ItemBox{} = item_box, item_uuid) do
      with {:ok, item} <- find_item(item_box, item_uuid),
           :ok <- check_weapon(item),
           {:ok, {updated_weapon, ammo}} <- Weapon.unload(item) do
        updated_item_box =
          item_box
          |> add_or_update_item(updated_weapon)
          |> add_or_update_item(ammo)

        {:ok, updated_item_box, updated_weapon}
      end
    end

    @spec stand_on(t(), Planet.tile()) :: t()
    def stand_on(%__MODULE__{} = item_box, tile) do
      struct!(item_box, stand_on: tile)
    end

    defp parse_item_types(types) do
      Enum.map(types, fn {category, subcategories} ->
        subcategories =
          case subcategories do
            "all" -> :all
            subcategories when is_list(subcategories) -> Enum.map(subcategories, &String.to_atom/1)
          end

        {category, subcategories}
      end)
      |> Enum.into(%{})
    end

    defp find_item(%ItemBox{} = item_box, item_uuid) do
      case Enum.find(item_box.items, fn item -> item.uuid == item_uuid end) do
        nil -> {:error, :no_item}
        item -> {:ok, item}
      end
    end

    defp add_or_update_item(%ItemBox{} = item_box, item) do
      case find_item(item_box, item.uuid) do
        {:ok, _} -> update_item(item_box, item)
        _ -> add_item(item_box, item)
      end
    end

    defp update_item(%ItemBox{} = item_box, new_item) do
      updated_items =
        Enum.map(item_box.items, fn item ->
          if item.uuid == new_item.uuid do
            new_item
          else
            item
          end
        end)

      struct!(item_box, items: updated_items)
    end

    defp check_weapon(%Weapon{}), do: :ok
    defp check_weapon(_), do: {:error, %Errors.NotApplicableError{}}
  end

  @spec allowed_item_types() :: list()
  def allowed_item_types, do: @item_types

  @spec allowed_item_box_types() :: list(item_box_type())
  def allowed_item_box_types, do: @allowed_item_box_types

  @spec movable_item_box_types() :: list(item_box_type())
  def movable_item_box_types do
    @item_boxes
    |> Enum.filter(fn {ib, _} -> ib.movable end)
    |> Enum.map(fn {ib, _} -> String.to_atom(ib.type) end)
  end

  @spec item_box_image(item_box_type()) :: image_name :: String.t()
  def item_box_image(item_box_type) when item_box_type in @allowed_item_box_types do
    get_item_box(item_box_type).image_name
  end

  @spec new_item(item_type(), attrs()) :: Item.t()
  def new_item(item_type, attrs) when item_type in @allowed_item_types and is_map(attrs) do
    case item_type do
      :weapon -> Weapon.new(attrs)
      :ammo -> Ammo.new(attrs)
      :melee_weapon -> MeleeWeapon.new(attrs)
      :helmet -> Helmet.new(attrs)
      :suit -> Suit.new(attrs)
      :boots -> Boots.new(attrs)
      :supply -> Supply.new(attrs)
      :tool -> Tool.new(attrs)
      :resource -> Resource.new(attrs)
      :implant -> Implant.new(attrs)
    end
  end

  @spec new_item_box(item_box_type(), list(Item.t())) :: ItemBox.t()
  def new_item_box(item_box_type, items) when item_box_type in @allowed_item_box_types and is_list(items) do
    stand_on = Enum.random([Tiles.tile(:snow).atom_value, Tiles.tile(:ice).atom_value])
    new_item_box(item_box_type, items, stand_on)
  end

  @spec new_item_box(item_box_type(), list(Item.t()), Planet.tile()) :: ItemBox.t()
  def new_item_box(item_box_type, items, stand_on)
      when item_box_type in @allowed_item_box_types and is_list(items) do
    generate_item_box(item_box_type, stand_on)
    |> struct!(items: items)
  end

  @spec generate_item_for_types(ItemBox.item_types()) :: Item.t()
  def generate_item_for_types(allowed_types) when is_map(allowed_types) or allowed_types == :all do
    item_type =
      case allowed_types do
        :all ->
          @weighted_item_types

        allowed_types ->
          @weighted_item_types
          |> Enum.filter(fn {type, _, _} -> type in Map.keys(allowed_types) end)
      end
      |> Enum.map(fn {item_type, _, weight} -> {item_type, weight} end)
      |> WeightedRandom.take_one()

    subtypes =
      case allowed_types do
        :all -> :all
        allowed_types -> Map.fetch!(allowed_types, item_type)
      end

    generate_item(item_type, subtypes)
  end

  @spec generate_item(item_type()) :: Item.t()
  def generate_item(item_type) when item_type in @allowed_item_types do
    generate_item(item_type, :all)
  end

  @spec generate_item(item_type(), ItemBox.item_types()) :: Item.t()
  def generate_item(item_type, :all) when item_type in @allowed_item_types do
    attrs =
      item_type
      |> get_items()
      |> WeightedRandom.take_one()
      |> AttrsDeterminator.determine_attrs()

    new_item(item_type, attrs)
  end

  def generate_item(item_type, allowed_subtypes) when item_type in @allowed_item_types when is_list(allowed_subtypes) do
    case allowed_subtypes do
      :all ->
        generate_item(item_type, :all)

      subtypes ->
        attrs =
          item_type
          |> get_items()
          |> Enum.filter(fn {raw_item, _} ->
            (Map.fetch!(raw_item, :subtype) |> String.to_atom()) in subtypes
          end)
          |> WeightedRandom.take_one()
          |> AttrsDeterminator.determine_attrs()

        new_item(item_type, attrs)
    end
  end

  @spec generate_item_by_id(item_type(), item_id(), count :: pos_integer()) :: Item.t()
  def generate_item_by_id(item_type, item_id, count \\ 1)
      when item_type in @allowed_item_types and is_atom(item_id) and is_integer(count) and count > 0 do
    attrs =
      item_type
      |> get_items()
      |> Enum.find(fn {item, _} -> String.to_atom(item.id) == item_id end)
      |> elem(0)
      |> AttrsDeterminator.determine_attrs()

    item_type
    |> new_item(attrs)
    |> maybe_set_count(count)
  end

  @spec generate_item_box() :: ItemBox.t()
  def generate_item_box do
    @outdoor_item_boxes
    |> WeightedRandom.take_one()
    |> ItemBox.from_map()
    |> add_items()
  end

  @spec generate_item_box(item_box_type(), Planet.tile()) :: ItemBox.t()
  def generate_item_box(item_box_type, stand_on \\ nil) when item_box_type in @allowed_item_box_types do
    item_box_type
    |> get_item_box()
    |> add_items()
    |> ItemBox.stand_on(stand_on)
  end

  @spec generate_item_box_by_placing(ItemBox.placing(), Planet.tile()) :: ItemBox.t()
  def generate_item_box_by_placing(placing, stand_on \\ nil) do
    @item_boxes
    |> Enum.filter(fn {ib, _} -> String.to_atom(ib.placing) == placing end)
    |> WeightedRandom.take_one()
    |> ItemBox.from_map()
    |> add_items()
    |> ItemBox.stand_on(stand_on)
  end

  @spec generate_item_box_from_enemy(Enemy.t()) :: ItemBox.t()
  def generate_item_box_from_enemy(%Enemy{} = enemy) do
    :monster_body
    |> get_item_box()
    |> add_items(enemy.max_items)
    |> ItemBox.stand_on(enemy.stand_on)
  end

  @spec generate_item_box_from_npc(Npc.t()) :: ItemBox.t()
  def generate_item_box_from_npc(%Npc{} = npc) do
    item_box =
      :human_body
      |> get_item_box()
      |> add_items(3)
      |> ItemBox.stand_on(npc.stand_on)

    struct!(item_box, items: [npc.weapon | item_box.items])
  end

  @spec get_items(item_type()) :: list()
  def get_items(category) do
    Map.fetch!(@items_attrs, category)
  end

  @spec item_disassemblable?(Item.item()) :: boolean()
  def item_disassemblable?(item) when is_struct(item) do
    if find_blueprint(item) do
      true
    else
      false
    end
  end

  @spec disassemble_item(Item.item()) :: {:ok, list(Resource.t())} | {:error, NotApplicableError.t()}
  def disassemble_item(item) when is_struct(item) do
    case find_blueprint(item) do
      %Blueprint{resources: resources} ->
        {:ok, resources}

      _ ->
        {:error, %NotApplicableError{}}
    end
  end

  @spec decrease_item_count(Item.item(), n :: pos_integer()) :: Item.item()
  def decrease_item_count(item, n \\ 1) when is_struct(item) and n > 0 do
    if Item.stackable?(item) do
      updated_value = (item.count - n) |> max(0)
      struct!(item, count: updated_value)
    else
      item
    end
  end

  defp find_blueprint(item) when is_struct(item) do
    item_type = Item.item_type(item)

    Blueprints.blueprints()
    |> Enum.find(fn %Blueprint{item: bp_item} ->
      Item.item_type(bp_item) == item_type && Item.id(bp_item) == Item.id(item)
    end)
  end

  defp maybe_set_count(item, count) do
    if Item.stackable?(item) do
      struct!(item, count: count)
    else
      item
    end
  end

  defp get_item_box(type) do
    @item_boxes
    |> Enum.find(fn {ib, _} -> String.to_atom(ib.type) == type end)
    |> elem(0)
    |> ItemBox.from_map()
  end

  defp add_items(%ItemBox{} = item_box, max_items \\ nil) do
    max_items = max_items || item_box.max_items

    items =
      case random_number(max_items + 1) - 1 do
        0 -> []
        1 -> [generate_item_for_types(item_box.item_types)]
        n -> Enum.map(1..n, fn _ -> generate_item_for_types(item_box.item_types) end)
      end

    struct!(item_box, items: items)
  end
end
