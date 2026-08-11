defmodule Europa.Server.Loot.Blueprints.BlueprintTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot.Blueprints.Blueprint
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Resource

  describe "new/2" do
    test "builds blueprint struct" do
      item = build(:weapon)
      resources = build_list(5, :resource)

      assert %Blueprint{item: ^item, resources: ^resources} = Blueprint.new(item, resources)
    end
  end

  describe "from_map/1" do
    test "builds blueprint from map" do
      assert %Blueprint{item: %Weapon{id: :guard_pistol, rounds_loaded: 0}, resources: [%Resource{id: :metal_plate}]} =
               Blueprint.from_map(%{
                 item_type: "weapon",
                 item_id: "guard_pistol",
                 resources: [%{id: "metal_plate", count: 6}]
               })
    end
  end
end
