defmodule Europa.Server.Planet.StormTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Planet.Storm
  alias Europa.Server.Planet

  describe "new/0" do
    test "builds storm struct" do
      assert %Storm{} = storm = Storm.new()

      assert storm.level |> is_integer()
      assert storm.max_level |> is_integer()
      assert storm.duration |> is_integer
      assert storm.direction in Planet.allowed_directions()
    end
  end

  describe "tick/1" do
    test "implements life cycle of a storm" do
      storm = build(:storm, duration: 3, level: 1, max_level: 3)

      assert {:ok, %Storm{level: 2, duration: 2} = storm} = Storm.tick(storm)
      assert {:ok, %Storm{level: 3, duration: 1} = storm} = Storm.tick(storm)
      assert {:ok, %Storm{level: 3, duration: 0} = storm} = Storm.tick(storm)
      assert {:ok, %Storm{level: 2, duration: 0} = storm} = Storm.tick(storm)
      assert {:ok, %Storm{level: 1, duration: 0} = storm} = Storm.tick(storm)
      assert :ended = Storm.tick(storm)
    end
  end
end
