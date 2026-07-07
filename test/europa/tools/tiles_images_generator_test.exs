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

  @png_ext ".png"
  @gif_ext ".gif"

  @png_fixture_tile_path "test/fixtures/tiles/tile.png"
  @gif_fixture_tile_path "test/fixtures/tiles/tile.gif"

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

    over_landscape = ["ol1", "ol2"]
    landscape = ["l1", "l2"]
    objects = ["o1", "o2"]
    movable_objects = ["broken_wall"]
    ready = ["r1", "r2"]
    enemies = ["e1", "e2"]
    loot = ["l1", "l2"]
    movable_loot = ["bag"]

    files_to_generate = %{
      @over_landscape => over_landscape,
      @landscape => landscape,
      @objects => objects ++ movable_objects,
      @ready => ready,
      @enemies => enemies,
      @loot => loot ++ movable_loot
    }

    on_exit(fn ->
      File.rm_rf!(@root_dir)
    end)

    {:ok,
     files_to_generate: files_to_generate,
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
    for {fixture_tile_path, ext} <- [{@png_fixture_tile_path, @png_ext}, {@gif_fixture_tile_path, @gif_ext}] do
      @fixture_tile_path fixture_tile_path
      @ext ext

      @tag slow: true
      test "generates landscapes (#{@ext})", %{
        files_to_generate: files_to_generate,
        over_landscape: over_landscape,
        landscape: landscape,
        movable_objects: movable_objects
      } do
        generate_files!(files_to_generate, @fixture_tile_path)

        assert_generated_tiles([landscape], @ext)
        assert_generated_tiles([over_landscape, landscape], @ext)
        assert_generated_tiles([movable_objects, over_landscape, landscape], @ext)
      end

      @tag slow: true
      test "generates ready (#{@ext})", %{ready: ready, files_to_generate: files_to_generate} do
        generate_files!(files_to_generate, @fixture_tile_path)
        assert_generated_tiles([ready], @ext)
      end

      @tag slow: true
      test "generates objects (#{@ext})", %{
        files_to_generate: files_to_generate,
        over_landscape: over_landscape,
        landscape: landscape,
        objects: objects,
        movable_objects: movable_objects,
        movable_loot: movable_loot
      } do
        generate_files!(files_to_generate, @fixture_tile_path)

        assert_generated_tiles([objects, landscape], @ext)
        assert_generated_tiles([objects, over_landscape, landscape], @ext)
        assert_generated_tiles([objects, movable_objects, over_landscape, landscape], @ext)
        assert_generated_tiles([objects, movable_loot, over_landscape, landscape], @ext)
        assert_generated_tiles([objects, movable_loot, landscape], @ext)
        assert_generated_tiles([objects, movable_loot, movable_objects, over_landscape, landscape], @ext)
      end

      @tag slow: true
      test "generates loot (#{@ext})", %{
        files_to_generate: files_to_generate,
        over_landscape: over_landscape,
        landscape: landscape,
        movable_objects: movable_objects,
        loot: loot
      } do
        generate_files!(files_to_generate, @fixture_tile_path)

        assert_generated_tiles([loot, landscape], @ext)
        assert_generated_tiles([loot, over_landscape, landscape], @ext)
        assert_generated_tiles([loot, movable_objects, over_landscape, landscape], @ext)
      end

      @tag slow: true
      test "generates enemies (#{@ext})", %{
        files_to_generate: files_to_generate,
        over_landscape: over_landscape,
        landscape: landscape,
        movable_objects: movable_objects,
        enemies: enemies,
        movable_loot: movable_loot
      } do
        generate_files!(files_to_generate, @fixture_tile_path)

        assert_generated_tiles([enemies, landscape], @ext)
        assert_generated_tiles([enemies, over_landscape, landscape], @ext)
        assert_generated_tiles([enemies, movable_objects, landscape], @ext)
        assert_generated_tiles([enemies, movable_loot, movable_objects, landscape], @ext)
      end
    end
  end

  def assert_generated_tiles(lists, ext \\ @png_ext) when is_list(lists) do
    assert TilesImagesGenerator.generate_tiles!(@root_dir) == :ok
    do_assert_generated_tiles(lists, ext, [])
  end

  defp do_assert_generated_tiles([], ext, acc) do
    generated_tiles = File.ls!(@final_tiles_path)
    assert file(Enum.reverse(acc), ext) in generated_tiles
  end

  defp do_assert_generated_tiles([list | rest], ext, acc) do
    Enum.each(list, fn elem ->
      do_assert_generated_tiles(rest, ext, [elem | acc])
    end)
  end

  defp file(filename, ext) when is_binary(filename) do
    filename <> ext
  end

  defp file(parts, ext) when is_list(parts) do
    Enum.join(parts, "_") <> ext
  end

  defp generate_files!(files_to_create, fixture_tile_path) when is_map(files_to_create) do
    Enum.each(files_to_create, fn {category, filenames} ->
      Enum.each(filenames, fn filename ->
        ext = String.split(fixture_tile_path, ".") |> List.last()
        path = Path.join([@root_dir, @base_dir, category, filename <> ".#{ext}"])
        File.cp!(fixture_tile_path, path)
      end)
    end)
  end
end
