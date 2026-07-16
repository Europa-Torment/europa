defmodule Europa.Server.Compass.TargetTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Compass
  alias Europa.Server.Compass.Target

  import Europa.Tools.Conf

  @max_description_length fetch_config!([Compass, :max_description_length])

  describe "new/2" do
    test "builds target struct" do
      coord = {10, 20}
      description = "Something"

      assert %Target{uuid: uuid, coord: ^coord, description: ^description} = Target.new(coord, description)
      assert is_binary(uuid)
    end

    test "crops long description" do
      coord = {10, 20}
      description = String.duplicate("a", @max_description_length + 1)

      target = Target.new(coord, description)

      assert String.length(target.description) == @max_description_length + 3
      assert String.ends_with?(target.description, "...")
    end
  end
end

defmodule Europa.Server.CompassTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Compass

  import Europa.Tools.Conf

  @max_targets fetch_config!([Compass, :max_targets])

  describe "new/0" do
    test "builds empty compass" do
      assert %Compass{current_target: nil, targets: []} = Compass.new()
    end
  end

  describe "add_target/2" do
    test "adds target (empty targets list)" do
      compass = build(:compass, targets: [])
      target = build(:compass_target)

      assert {:ok, %Compass{targets: [^target]}} = Compass.add_target(compass, target)
    end

    test "adds target (with exist targets)" do
      [target1, target2] = build_list(2, :compass_target)
      compass = build(:compass, targets: [target1])

      assert {:ok, %Compass{targets: [^target2, ^target1]}} = Compass.add_target(compass, target2)
    end

    test "respects max targets limit" do
      targets = build_list(@max_targets, :compass_target)
      target = build(:compass_target)

      compass = build(:compass, targets: targets)

      assert {:error, {:limit_reached, @max_targets}} = Compass.add_target(compass, target)
    end
  end

  describe "follow_target/2" do
    test "follows target" do
      [target1, target2] = build_list(2, :compass_target)
      compass = build(:compass, targets: [target1, target2])

      assert {:ok, %Compass{current_target: ^target1, targets: [^target2]}} =
               Compass.follow_target(compass, target1.uuid)
    end

    test "follow target (already followed)" do
      [target1, target2] = build_list(2, :compass_target)
      compass = build(:compass, current_target: target2, targets: [target1])

      assert {:ok, ^compass} =
               Compass.follow_target(compass, target2.uuid)
    end

    test "returns not_found error" do
      compass = build(:compass)
      uuid = Ecto.UUID.generate()

      assert {:error, :not_found} = Compass.follow_target(compass, uuid)
    end
  end

  describe "unfollow_target/1" do
    test "puts current target to targets list" do
      [target1, target2] = build_list(2, :compass_target)
      compass = build(:compass, targets: [target1], current_target: target2)

      assert %Compass{current_target: nil, targets: [^target2, ^target1]} = Compass.unfollow_target(compass)
    end

    test "does nothing when no followed target" do
      compass = build(:compass, current_target: nil)
      assert Compass.unfollow_target(compass) == compass
    end
  end

  describe "delete_target/2" do
    test "deletes given target" do
      [target1, target2] = build_list(2, :compass_target)
      compass = build(:compass, targets: [target1, target2])

      assert {:ok, %Compass{targets: [^target1]}} = Compass.delete_target(compass, target2.uuid)
    end

    test "deletes given target (current target)" do
      [target1, target2] = build_list(2, :compass_target)
      compass = build(:compass, targets: [target1], current_target: target2)

      assert {:ok, %Compass{targets: [^target1], current_target: nil}} = Compass.delete_target(compass, target2.uuid)
    end

    test "returns not_found error" do
      compass = build(:compass)
      uuid = Ecto.UUID.generate()

      assert {:error, :not_found} = Compass.delete_target(compass, uuid)
    end
  end
end
