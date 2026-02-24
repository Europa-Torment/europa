defmodule Europa.Tools.TilesImagesGeneratorTest do
  use ExUnit.Case

  alias Europa.Tools.TilesImagesGenerator

  @root_dir "test/test_images"
  @base_dir "/tile_images"

  @over_landscape "/over_landscape"
  @landscape "/landscape"
  @objects "/objects"
  @ready "/ready"

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
    File.mkdir!(Path.join([@root_dir, @base_dir, @ready]))

    over_landscape = ["ol_1", "ol_2", "ol_3"]
    landscape = ["l1", "l2", "l3"]
    objects = ["o1", "o2", "o3"]
    ready = ["r1", "r2", "r3"]

    generate_files!(%{@over_landscape => over_landscape, @landscape => landscape, @objects => objects, @ready => ready})

    on_exit(fn ->
      File.rm_rf!(@root_dir)
    end)

    {:ok, over_landscape: over_landscape, landscape: landscape, objects: objects, ready: ready}
  end

  describe "generate_tiles!/1" do
    test "generates expected amount of tiles", %{
      over_landscape: over_landscape,
      landscape: landscape,
      objects: objects,
      ready: ready
    } do
      assert TilesImagesGenerator.generate_tiles!(@root_dir) == :ok

      generated_files_count =
        @final_tiles_path
        |> File.ls!()
        |> Enum.count()

      over_landscape_count = Enum.count(over_landscape)
      landscape_count = Enum.count(landscape)
      objects_count = Enum.count(objects)
      ready_count = Enum.count(ready)

      expected_count =
        ready_count + landscape_count +
          over_landscape_count * landscape_count +
          landscape_count * objects_count +
          over_landscape_count * landscape_count * objects_count

      assert generated_files_count == expected_count
    end

    test "generates expected tiles", %{
      over_landscape: over_landscape,
      landscape: landscape,
      objects: objects,
      ready: ready
    } do
      assert TilesImagesGenerator.generate_tiles!(@root_dir) == :ok

      generated_tiles =
        @final_tiles_path
        |> File.ls!()

      expected_ready = Enum.map(ready, &(&1 <> @ext))
      expected_landscape = Enum.map(landscape, &(&1 <> @ext))

      expected_overlandscape_plus_landscape =
        Enum.map(over_landscape, fn ol ->
          Enum.map(landscape, fn l ->
            ol <> "_" <> l <> @ext
          end)
        end)
        |> List.flatten()

      expected_landscape_plus_objects =
        Enum.map(landscape, fn l ->
          Enum.map(objects, fn o ->
            o <> "_" <> l <> @ext
          end)
        end)
        |> List.flatten()

      expected_overlandscape_plus_landscape_plus_objects =
        Enum.map(over_landscape, fn ol ->
          Enum.map(landscape, fn l ->
            Enum.map(objects, fn o ->
              o <> "_" <> ol <> "_" <> l <> @ext
            end)
          end)
        end)
        |> List.flatten()

      assert Enum.sort(generated_tiles) ==
               Enum.sort(
                 expected_ready ++
                   expected_landscape ++
                   expected_overlandscape_plus_landscape ++
                   expected_landscape_plus_objects ++ expected_overlandscape_plus_landscape_plus_objects
               )
    end
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
