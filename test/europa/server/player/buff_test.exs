defmodule Europa.Server.Player.BuffTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Player.Buff

  describe "from_map/1" do
    test "builds buff struct" do
      assert Buff.from_map(%{stat_name: "max_warm", value: 10, duration: 20}) == %Buff{
               stat_name: :max_warm,
               value: 10,
               duration: 20
             }
    end

    test "validates value" do
      assert_raise RuntimeError, fn ->
        Buff.from_map(%{stat_name: "max_warm", value: "fake", duration: 20})
      end
    end

    test "validates duration" do
      assert_raise RuntimeError, fn ->
        Buff.from_map(%{stat_name: "max_warm", value: 10, duration: -20})
      end
    end
  end

  describe "decrease_duration/1" do
    test "decreases buff duration" do
      buff = build(:buff)
      assert %Buff{duration: new_duration} = Buff.decrease_duration(buff)
      assert new_duration == buff.duration - 1
    end

    test "doesnt decreases 0" do
      buff = build(:buff, duration: 0)
      assert %Buff{duration: 0} = Buff.decrease_duration(buff)
    end
  end
end
