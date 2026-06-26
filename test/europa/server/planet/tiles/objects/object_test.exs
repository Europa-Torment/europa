defmodule Europa.Server.Planet.Tiles.Objects.ObjectTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object

  @snow Tiles.tile(:snow).atom_value

  describe "stand_on/2" do
    setup do
      object = build(:object, stand_on: nil)
      {:ok, object: object}
    end

    test "changes stand_on", %{object: object} do
      assert %Object{stand_on: @snow} = Object.stand_on(object, @snow)
    end
  end

  describe "transform/1" do
    test "returns tile atom value" do
      object = build(:object, transforms_to_tile: :snow)
      assert Object.transform(object) == @snow
    end

    test "returns unchanged object if not transformable" do
      object = build(:object, transforms_to_tile: nil)
      assert Object.transform(object) == object
    end
  end
end
