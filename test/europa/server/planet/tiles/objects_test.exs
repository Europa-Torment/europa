defmodule Europa.Server.Planet.Tiles.ObjectsTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object

  describe "object/1" do
    test "returns object by name" do
      assert %Object{} = Objects.object(:door_up)
    end
  end

  describe "objects/0" do
    test "returns objects" do
      objects = Objects.objects()
      assert Enum.all?(objects, fn {name, object} -> assert is_atom(name) && object?(object) end)
    end
  end

  defp object?(%Object{}), do: true
  defp object?(_), do: false
end
