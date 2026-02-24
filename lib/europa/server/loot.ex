defmodule Europa.Server.Loot do
  use TypedStruct

  alias Europa.Server.Planet

  alias Europa.Tools.Types
  alias Europa.Tools.AttrsDeterminator
  alias Europa.Tools.FilesCache

  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Loot.Helmet
  alias Europa.Server.Loot.Suit
  alias Europa.Server.Loot.Boots

  import Europa.Tools.Randomizer
  import Europa.Tools.Conf

  @max_items_in_item_box fetch_config!([:random_params, :loot, :max_items_in_item_box])

  @allowed_item_types [:weapon, :ammo, :helmet, :suit, :boots]
  @allowed_item_box_types [:box, :monster_body, :human_body, :crashed_shuttle]

  @templates_path "/items/"

  @filenames %{
    weapon: "weapons.json",
    ammo: "ammo.json",
    helmet: "helmets.json",
    suit: "suits.json",
    boots: "boots.json"
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
    alias Europa.Server.Loot.Helmet
    alias Europa.Server.Loot.Suit
    alias Europa.Server.Loot.Boots

    @type item() :: Weapon.t() | Ammo.t() | Helmet.t() | Suit.t() | Boots.t()

    @spec item_type(item()) :: Loot.item_type()
    def item_type(item)

    @spec composed_name(item()) :: String.t()
    def composed_name(item)

    @spec readable_attrs(item()) :: list()
    def readable_attrs(item)

    @spec equipable?(item()) :: boolean()
    def equipable?(item)

    @spec equip(item()) :: {:ok, item()} | {:error, Errors.NotApplicableError.t()}
    def equip(item)

    @spec unequip(item()) :: {:ok, item()} | {:error, Errors.NotApplicableError.t()}
    def unequip(item)

    @spec player_stats_changes(item()) :: map()
    def player_stats_changes(item)
  end

  defmodule ItemBox do
    use Gettext, backend: Europa.Gettext

    alias Europa.Server.Loot

    typedstruct enforce: true do
      field :type, Loot.item_box_type()
      field :items, list(Loot.Item.item())
      field :stand_on, Planet.tile()
    end

    @spec readable_name(t()) :: String.t()
    def readable_name(%ItemBox{type: type}) do
      case type do
        :box -> gettext("Factory box")
        :monster_body -> gettext("Monster body")
        :human_body -> gettext("Human body")
        :crashed_shuttle -> gettext("Crashed shuttle")
      end
    end

    @spec take_item(ItemBox.t(), Loot.uuid()) :: {:error, :no_item} | {:ok, Item.t(), ItemBox.t()}
    def take_item(%ItemBox{items: items} = item_box, item_uuid) do
      case Enum.find(items, fn item -> item.uuid == item_uuid end) do
        nil ->
          {:error, :no_item}

        item ->
          updated_items = List.delete(items, item)
          {:ok, item, struct(item_box, items: updated_items)}
      end
    end

    @spec stand_on(t(), Planet.tile()) :: t()
    def stand_on(%__MODULE__{} = item_box, tile) do
      struct(item_box, stand_on: tile)
    end
  end

  @spec allowed_item_types() :: [item_type(), ...]
  def allowed_item_types, do: @allowed_item_types

  @spec allowed_item_box_types() :: [item_box_type(), ...]
  def allowed_item_box_types, do: @allowed_item_box_types

  @spec new_item(item_type(), attrs()) :: Item.t()
  def new_item(item_type, attrs) when item_type in @allowed_item_types and is_map(attrs) do
    case item_type do
      :weapon -> Weapon.new(attrs)
      :ammo -> Ammo.new(attrs)
      :helmet -> Helmet.new(attrs)
      :suit -> Suit.new(attrs)
      :boots -> Boots.new(attrs)
    end
  end

  @spec new_item_box(item_box_type(), list(Item.t())) :: ItemBox.t()
  def new_item_box(item_box_type, items) when item_box_type in @allowed_item_box_types and is_list(items) do
    stand_on = Enum.random([Planet.snow(), Planet.ice()])
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

  @spec generate_item() :: Item.t()
  def generate_item do
    @allowed_item_types
    |> Enum.random()
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
    @allowed_item_box_types
    |> Enum.random()
    |> generate_item_box()
  end

  @spec generate_item_box(item_box_type()) :: ItemBox.t()
  def generate_item_box(item_box_type) when item_box_type in @allowed_item_box_types do
    stand_on = Enum.random([Planet.snow(), Planet.ice()])
    generate_item_box(item_box_type, stand_on)
  end

  @spec generate_item_box(item_box_type(), Planet.tile()) :: ItemBox.t()
  def generate_item_box(item_box_type, stand_on) when item_box_type in @allowed_item_box_types do
    items =
      case random_number(@max_items_in_item_box) do
        1 -> [generate_item()]
        n -> Enum.map(1..n, fn _ -> generate_item() end)
      end

    new_item_box(item_box_type, items, stand_on)
  end

  defp parse_file(category) do
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
