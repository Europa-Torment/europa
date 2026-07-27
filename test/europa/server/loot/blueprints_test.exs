defmodule Europa.Server.Loot.BlueprintsTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Blueprints
  alias Europa.Server.Loot.Blueprints.Blueprint
  alias Europa.Server.Loot.Resource

  describe "blueprints/1" do
    test "returns list of blueprints" do
      blueprints = Blueprints.blueprints()

      assert Enum.all?(blueprints, fn %Blueprint{item: item, resources: resources} ->
               Loot.Item.item_type(item) |> is_atom() && Enum.all?(resources, &resource?/1)
             end)
    end

    test "returns listi of blueprints with given item type" do
      for item_type <- [:weapon, :tool] do
        blueprints = Blueprints.blueprints(item_type)

        assert Enum.all?(blueprints, fn %Blueprint{item: item} ->
                 Loot.Item.item_type(item) == item_type
               end)
      end
    end
  end

  defp resource?(%Resource{}), do: true
  defp resource?(_), do: false
end
