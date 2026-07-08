defmodule Europa.Server.Planet.Tiles.Objects.Object.TransformTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Tiles.Objects.Object.Transform

  describe "set_transform_requirements/2" do
    test "sets transform_requirements" do
      transform = build(:object_transform, transform_requirements: nil)
      requirements = {:tools, build_list(3, :tool)}

      assert %Transform{transform_requirements: ^requirements} =
               Transform.set_transform_requirements(transform, requirements)
    end
  end
end
