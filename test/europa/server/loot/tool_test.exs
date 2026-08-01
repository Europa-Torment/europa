defmodule Europa.Server.Loot.ToolTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Loot.Tool
  alias Europa.Server.Errors.NotApplicableError

  describe "new/1" do
    test "raises when tool stackable and has durability at same time" do
      attrs = %{
        id: "tool",
        name: "tool",
        subtype: "common",
        description: "tool",
        count: 1,
        weight: 1.0,
        sound_name: "sound",
        stackable: true,
        properties: %{
          durability: 100
        }
      }

      assert_raise RuntimeError, fn ->
        Tool.new(attrs)
      end
    end

    test "raises when tool not stackable and count > 1" do
      attrs = %{
        id: "tool",
        name: "tool",
        subtype: "common",
        description: "tool",
        count: 10,
        weight: 1.0,
        sound_name: "sound",
        stackable: false,
        properties: %{
          durability: 100
        }
      }

      assert_raise RuntimeError, fn ->
        Tool.new(attrs)
      end
    end

    test "raises when tool is usable but doesn't has use_cost" do
      attrs = %{
        id: "tool",
        name: "tool",
        subtype: "common",
        description: "tool",
        count: 10,
        weight: 1.0,
        sound_name: "sound",
        stackable: true,
        using_type: %{put_object: "bonfire"},
        properties: %{
          durability: 100
        }
      }

      assert_raise RuntimeError, fn ->
        Tool.new(attrs)
      end
    end
  end

  describe "switch/1" do
    test "switches tool state" do
      tool = build(:tool, using_type: :switch, active?: false)
      assert {:ok, %Tool{active?: true} = tool} = Tool.switch(tool)
      assert {:ok, %Tool{active?: false}} = Tool.switch(tool)
    end

    test "returns NotApplicableError when tool is not switchable" do
      tool = build(:tool, using_type: {:put_object, :bonfire})
      assert {:error, %NotApplicableError{}} = Tool.switch(tool)
    end
  end

  describe "with_durability?/1" do
    test "returns false if tools without durability" do
      tool = build(:tool)
      assert Tool.with_durability?(tool) == false
    end

    test "returns true if tool with durability" do
      tool = build(:tool, properties: build(:tool_properties, durability: 100))
      assert Tool.with_durability?(tool) == true
    end
  end

  describe "decrease_durability/1" do
    test "decreases tool durability" do
      tool = build(:tool, properties: build(:tool_properties, durability: 100))
      assert {:ok, %Tool{properties: %Tool.Properties{durability: 99}}} = Tool.decrease_durability(tool)
    end

    test "returns NotApplicable error" do
      tool = build(:tool, properties: build(:tool_properties, durability: nil))
      assert {:error, %NotApplicableError{}} = Tool.decrease_durability(tool)
    end
  end
end
