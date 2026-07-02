defmodule Europa.Server.Planet.Tiles.Objects.ObjectTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object

  @snow Tiles.tile(:snow).atom_value
  @bonfire Objects.object(:bonfire)

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
    test "transforms object to tile" do
      object = build(:object, transforms_to: {:tile, :snow})
      assert Object.transform(object) == @snow
    end

    test "transforms object to object" do
      object = build(:object, transforms_to: {:object, :bonfire})
      assert Object.transform(object) == @bonfire
    end

    test "returns unchanged object if not transformable" do
      object = build(:object, transforms_to: nil)
      assert Object.transform(object) == object
    end
  end

  describe "set_transform_requirements/2" do
    test "sets transform_requirements" do
      object = build(:object, transform_requirements: nil)
      requirements = build_list(3, :tool)

      assert %Object{transform_requirements: ^requirements} = Object.set_transform_requirements(object, requirements)
    end
  end
end
