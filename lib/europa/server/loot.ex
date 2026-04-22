defmodule Europa.Server.Loot do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet

  alias Europa.Tools.Types
  alias Europa.Tools.AttrsDeterminator
  alias Europa.Tools.FilesCache

  alias Europa.Server.Planet.Tiles

  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.MeleeWeapon
  alias Europa.Server.Loot.Helmet
  alias Europa.Server.Loot.Suit
  alias Europa.Server.Loot.Boots
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Errors

  import Europa.Tools.Randomizer

  @weighted_item_types [
    {:weapon, gettext("Weapons"), 0.4},
    {:ammo, gettext("Ammo"), 0.7},
    {:melee_weapon, gettext("Melee weapons"), 0.5},
    {:supply, gettext("Supplies"), 1.0},
    {:helmet, gettext("Helmets"), 0.4},
    {:suit, gettext("Suits"), 0.2},
    {:boots, gettext("Boots"), 0.4}
  ]

  @item_types Enum.map(@weighted_item_types, fn {k, v, _} -> {k, v} end)

  @allowed_item_types Enum.map(@item_types, fn {k, _v} -> k end)

  @outdoor_item_boxes %{
    box: %{max_items: 10, item_types: :all},
    monster_body: %{max_items: 4, item_types: [:weapon, :ammo, :melee_weapon, :helmet, :suit, :boots]},
    human_body: %{max_items: 5, item_types: :all},
    crashed_shuttle: %{max_items: 5, item_types: :all},
    bunch: %{max_items: 3, item_types: :all}
  }

  @furniture_item_boxes %{
    cupboard: %{max_items: 6, item_types: :all},
    refrigerator: %{max_items: 6, item_types: [:supply]}
  }

  @allowed_item_boxes Map.merge(@outdoor_item_boxes, @furniture_item_boxes)

  @allowed_item_box_types Map.keys(@allowed_item_boxes)

  @templates_path "/items/"

  @filenames %{
    weapon: "weapons.json",
    ammo: "ammo.json",
    melee_weapon: "melee_weapons.json",
    helmet: "helmets.json",
    suit: "suits.json",
    boots: "boots.json",
    supply: "supplies.json"
  }

  @type item_type :: unquote(Types.one_of(@allowed_item_types))
  @type item_box_type :: unquote(Types.one_of(@allowed_item_box_types))

  @type attrs :: map()

  @type uuid :: Ecto.UUID.t()

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

    @type item() :: Weapon.t() | Ammo.t() | MeleeWeapon.t() | Helmet.t() | Suit.t() | Boots.t() | Supply.t()
    @type weight() :: number()

    @spec item_type(item()) :: Loot.item_type()
    def item_type(item)

    @spec composed_name(item()) :: String.t()
    def composed_name(item)

    @spec readable_attrs(item()) :: list()
    def readable_attrs(item)

    @spec consumable?(item()) :: boolean()
    def consumable?(item)

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

    typedstruct do
      field :type, Loot.item_box_type(), enforce: true
      field :items, list(Loot.Item.item()), enforce: true
      field :stand_on, Planet.tile()
    end

    @spec readable_name(t()) :: String.t()
    def readable_name(%ItemBox{type: type}) do
      case type do
        :box -> gettext("Factory box")
        :monster_body -> gettext("Monster body")
        :human_body -> gettext("Human body")
        :crashed_shuttle -> gettext("Crashed shuttle")
        :bunch -> gettext("Bunch of items")
        :cupboard -> gettext("Cupboard")
        :refrigerator -> gettext("Refrigerator")
      end
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

  @spec allowed_item_box_types() :: [item_box_type(), ...]
  def allowed_item_box_types, do: @allowed_item_box_types

  @spec furniture_item_box_types() :: [item_box_type(), ...]
  def furniture_item_box_types do
    Map.keys(@furniture_item_boxes)
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
    %ItemBox{
      type: item_box_type,
      items: items,
      stand_on: stand_on
    }
  end

  @spec generate_item_for_types(list() | :all) :: Item.t()
  def generate_item_for_types(allowed_types) when is_list(allowed_types) or allowed_types == :all do
    case allowed_types do
      :all ->
        @weighted_item_types

      allowed_types ->
        @weighted_item_types
        |> Enum.filter(fn {type, _, _} -> type in allowed_types end)
    end
    |> Enum.map(fn {item_type, _, weight} -> {item_type, weight} end)
    |> WeightedRandom.take_one()
    |> generate_item()
  end

  @spec generate_item(item_type()) :: Item.t()
  def generate_item(item_type) when item_type in @allowed_item_types do
    attrs =
      item_type
      |> parse_file()
      |> WeightedRandom.take_one()
      |> AttrsDeterminator.determine_attrs()

    new_item(item_type, attrs)
  end

  @spec generate_item_box() :: ItemBox.t()
  def generate_item_box do
    @outdoor_item_boxes
    |> Map.keys()
    |> Enum.random()
    |> generate_item_box()
  end

  @spec generate_item_box(item_box_type(), Planet.tile()) :: ItemBox.t()
  def generate_item_box(item_box_type, stand_on \\ nil) when item_box_type in @allowed_item_box_types do
    item_box_params = Map.fetch!(@allowed_item_boxes, item_box_type)
    allowed_item_types = item_box_params.item_types
    max_items = item_box_params.max_items

    items =
      case random_number(max_items) do
        1 -> [generate_item_for_types(allowed_item_types)]
        n -> Enum.map(1..n, fn _ -> generate_item_for_types(allowed_item_types) end)
      end

    new_item_box(item_box_type, items, stand_on)
  end

  @spec parse_file(item_type()) :: map()
  def parse_file(category) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, Map.fetch!(@filenames, category)])

    case FilesCache.get(path) do
      {:ok, cached_file} ->
        cached_file

      _ ->
        path
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
        |> Enum.map(fn attrs -> {attrs, attrs.random_weight} end)
        |> tap(fn file_content -> FilesCache.put(path, file_content) end)
    end
  end
end
