defmodule Europa.Server.Loot.Blueprints do
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Item
  alias Europa.Server.Loot.Blueprints.Blueprint
  alias Europa.Server.Loot.Utils.FilesReader

  @blueprints_filename "blueprints.json"
  @blueprints FilesReader.parse_blueprints_file(@blueprints_filename) |> Enum.map(&Blueprint.from_map/1)

  @spec blueprints(Loot.item_type() | :all) :: list(Blueprint.t())
  def blueprints(item_type \\ :all) do
    case item_type do
      :all -> @blueprints
      type -> Enum.filter(@blueprints, &(Item.item_type(&1.item) == type))
    end
  end
end
