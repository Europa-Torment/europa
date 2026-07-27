defmodule Europa.Server.Loot.Blueprints.BlueprintTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot.Blueprints.Blueprint

  describe "new/2" do
    test "builds blueprint struct" do
      item = build(:weapon)
      resources = build_list(5, :resource)

      assert %Blueprint{item: ^item, resources: ^resources} = Blueprint.new(item, resources)
    end
  end

  describe "from_map/1" do
    test "builds blueprint from map" do
      assert %Blueprint{} =
               Blueprint.from_map(%{
                 item_type: "resource",
                 item_id: "long_barrel",
                 resources: [%{id: "metal_plate", count: 6}]
               })
    end
  end
end
