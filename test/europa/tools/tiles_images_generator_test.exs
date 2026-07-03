defmodule Europa.Tools.TilesImagesGeneratorTest do
  use ExUnit.Case

  alias Europa.Tools.TilesImagesGenerator

  @root_dir "test/test_images"
  @base_dir "/tile_images"

  @over_landscape "/over_landscape"
  @landscape "/landscape"
  @objects "/objects"
  @ready "/ready"
  @enemies "/enemies"
  @loot "/loot"

  @tmp_base "/tmp"

  @ext ".png"

  @fixture_tile_path "test/fixtures/tiles/tile.png"

  @final_tiles_path Path.join([@root_dir, @base_dir, @tmp_base, @ready])

  setup do
    File.rm_rf!(@root_dir)
    File.mkdir!(@root_dir)

    File.mkdir!(Path.join([@root_dir, @base_dir]))
    File.mkdir!(Path.join([@root_dir, @base_dir, @tmp_base]))

    File.mkdir!(Path.join([@root_dir, @base_dir, @over_landscape]))
    File.mkdir!(Path.join([@root_dir, @base_dir, @landscape]))
    File.mkdir!(Path.join([@root_dir, @base_dir, @objects]))
    File.mkdir!(Path.join([@root_dir, @base_dir, @enemies]))
    File.mkdir!(Path.join([@root_dir, @base_dir, @loot]))
    File.mkdir!(Path.join([@root_dir, @base_dir, @ready]))

    over_landscape = ["ol1", "ol2", "ol3"]
    landscape = ["l1", "l2", "l3"]
    objects = ["o1", "o2", "o3"]
    movable_objects = ["broken_wall"]
    ready = ["r1", "r2", "r3"]
    enemies = ["e1", "e2", "e3"]
    loot = ["l1", "l2", "l3"]
    movable_loot = ["bag"]

    generate_files!(%{
      @over_landscape => over_landscape,
      @landscape => landscape,
      @objects => objects ++ movable_objects,
      @ready => ready,
      @enemies => enemies,
      @loot => loot ++ movable_loot
    })

    on_exit(fn ->
      File.rm_rf!(@root_dir)
    end)

    {:ok,
     over_landscape: over_landscape,
     landscape: landscape,
     objects: objects,
     movable_objects: movable_objects,
     ready: ready,
     enemies: enemies,
     loot: loot,
     movable_loot: movable_loot}
  end

  describe "generate_tiles!/1" do
    test "generates landscapes", %{
      over_landscape: over_landscape,
      landscape: landscape,
      movable_objects: movable_objects
    } do
      assert_generated_tiles([landscape])
      assert_generated_tiles([over_landscape, landscape])
      assert_generated_tiles([movable_objects, over_landscape, landscape])
    end

    test "generates ready", %{ready: ready} do
      assert_generated_tiles([ready])
    end

    test "generates objects", %{
      over_landscape: over_landscape,
      landscape: landscape,
      objects: objects,
      movable_objects: movable_objects,
      movable_loot: movable_loot
    } do
      assert_generated_tiles([objects, landscape])
      assert_generated_tiles([objects, over_landscape, landscape])
      assert_generated_tiles([objects, movable_objects, over_landscape, landscape])
      assert_generated_tiles([objects, movable_loot, over_landscape, landscape])
      assert_generated_tiles([objects, movable_loot, landscape])
      assert_generated_tiles([objects, movable_loot, movable_objects, over_landscape, landscape])
    end

    test "generates loot", %{
      over_landscape: over_landscape,
      landscape: landscape,
      movable_objects: movable_objects,
      loot: loot
    } do
      assert_generated_tiles([loot, landscape])
      assert_generated_tiles([loot, over_landscape, landscape])
      assert_generated_tiles([loot, movable_objects, over_landscape, landscape])
    end

    test "generates enemies", %{
      over_landscape: over_landscape,
      landscape: landscape,
      movable_objects: movable_objects,
      enemies: enemies,
      movable_loot: movable_loot
    } do
      assert_generated_tiles([enemies, landscape])
      assert_generated_tiles([enemies, over_landscape, landscape])
      assert_generated_tiles([enemies, movable_objects, landscape])
      assert_generated_tiles([enemies, movable_loot, movable_objects, landscape])
    end
  end

  def assert_generated_tiles(lists) when is_list(lists) do
    assert TilesImagesGenerator.generate_tiles!(@root_dir) == :ok
    do_assert_generated_tiles(lists, [])
  end

  defp do_assert_generated_tiles([], acc) do
    generated_tiles = File.ls!(@final_tiles_path)
    assert file(Enum.reverse(acc)) in generated_tiles
  end

  defp do_assert_generated_tiles([list | rest], acc) do
    Enum.each(list, fn elem ->
      do_assert_generated_tiles(rest, [elem | acc])
    end)
  end

  defp file(filename) when is_binary(filename) do
    filename <> @ext
  end

  defp file(parts) when is_list(parts) do
    Enum.join(parts, "_") <> @ext
  end

  defp generate_files!(files_to_create) when is_map(files_to_create) do
    Enum.each(files_to_create, fn {category, filenames} ->
      Enum.each(filenames, fn filename ->
        path = Path.join([@root_dir, @base_dir, category, filename <> @ext])
        File.cp!(@fixture_tile_path, path)
      end)
    end)
  end
end
