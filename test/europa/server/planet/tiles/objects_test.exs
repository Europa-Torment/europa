defmodule Europa.Server.Planet.Tiles.ObjectsTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object

  describe "object/1" do
    test "returns object by name" do
      assert %Object{} = Objects.object(:door_up)
    end
  end
end
