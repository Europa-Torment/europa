defmodule Europa.Server.Planet.Tiles.Objects.ObjectTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Loot
  alias Europa.Server.Loot.ItemBox

  @snow_tile Tiles.tile(:snow)
  @snow @snow_tile.atom_value
  @bonfire Objects.object(:bonfire)

  @transform_name :name

  describe "stand_on/2" do
    setup do
      object = build(:object, stand_on: nil)
      {:ok, object: object}
    end

    test "changes stand_on", %{object: object} do
      assert %Object{stand_on: @snow} = Object.stand_on(object, @snow)
    end
  end

  describe "fetch_transform/2" do
    test "returns transform" do
      transform = build(:object_transform, name: @transform_name, transforms_to: {:tile, :snow}, name: :transform_name)
      object = build(:object, transforms: [transform])
      assert Object.fetch_transform!(object, transform.name) == transform
    end
  end

  describe "transform/2" do
    test "transforms object to tile" do
      object =
        build(:object, transforms: [build(:object_transform, name: @transform_name, transforms_to: {:tile, :snow})])

      assert Object.transform(object, @transform_name) == @snow
    end

    test "transforms object to object" do
      object =
        build(:object,
          transforms: [build(:object_transform, name: @transform_name, transforms_to: {:object, :bonfire})]
        )

      assert Object.transform(object, @transform_name) == @bonfire
    end

    test "transforms object to item_box" do
      item_box_type = :crashed_shuttle

      object =
        build(:object,
          transforms: [build(:object_transform, name: @transform_name, transforms_to: {:item_box, item_box_type})]
        )

      assert %ItemBox{type: ^item_box_type} = Object.transform(object, @transform_name)
    end

    test "transforms object to nothing (to object stand_on tile)" do
      object =
        build(:object,
          transforms: [build(:object_transform, name: @transform_name, transforms_to: :nothing)],
          stand_on: @snow
        )

      assert Object.transform(object, @transform_name) == @snow
    end

    test "returns unchanged object if not transformable" do
      object = build(:object, transforms: [])
      assert Object.transform(object, @transform_name) == object
    end
  end

  describe "add_transform/2" do
    test "adds transform" do
      transform1 = build(:object_transform)
      transform2 = build(:object_transform)

      object1 = build(:object, transforms: [])
      object2 = build(:object, transforms: [transform1])

      assert %Object{transforms: [^transform1]} = Object.add_transform(object1, transform1)
      assert %Object{transforms: [^transform1, ^transform2]} = Object.add_transform(object2, transform2)
    end
  end

  describe "transform_confirmation/1" do
    test "with required tools" do
      tools = build_list(3, :tool)
      requirements = {:tools, tools}

      object =
        build(:object,
          transforms: [build(:object_transform, name: @transform_name, transform_requirements: requirements)]
        )

      assert Object.transform_confirmation(object, @transform_name) == {:required_tools, tools}
    end

    test "with change_confirmation (transforms to tile)" do
      object =
        build(:object,
          transforms: [
            build(:object_transform,
              name: @transform_name,
              transform_requirements: :change_confirmation,
              transforms_to: {:tile, :snow}
            )
          ]
        )

      assert Object.transform_confirmation(object, @transform_name) == {:change, object.name, @snow_tile.readable_name}
    end

    test "with change_confirmation (transforms to object)" do
      object =
        build(:object,
          transforms: [
            build(:object_transform,
              name: @transform_name,
              transform_requirements: :change_confirmation,
              transforms_to: {:object, :bonfire}
            )
          ]
        )

      assert Object.transform_confirmation(object, @transform_name) == {:change, object.name, @bonfire.name}
    end

    test "with change_confirmation (transforms to item_box)" do
      item_box_type = :bag

      object =
        build(:object,
          transforms: [
            build(:object_transform,
              name: @transform_name,
              transform_requirements: :change_confirmation,
              transforms_to: {:item_box, item_box_type}
            )
          ]
        )

      item_box = Loot.generate_item_box(item_box_type)

      assert Object.transform_confirmation(object, @transform_name) == {:change, object.name, item_box.readable_name}
    end

    test "with change_confirmation (transforms to nothing)" do
      object =
        build(:object,
          transforms: [
            build(:object_transform,
              name: @transform_name,
              transform_requirements: :change_confirmation,
              transforms_to: :nothing
            )
          ]
        )

      assert Object.transform_confirmation(object, @transform_name) == {:change, object.name, :delete}
    end
  end
end
