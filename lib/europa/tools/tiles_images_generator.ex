defmodule Europa.Tools.TilesImagesGenerator do
  @moduledoc """
  Tiles images generator.
  Makes artists' work easier: automates the creation of tiles images by overlaying them on top of each other.

  There are 4 types of tiles:

  `landscape` - ladndscape tiles such as snow, water, ice, etc

  `over_landscape` - tiles that should be overlayed on `landscape` tiles, example: bloody versions of each landscape tile

  `objects` - tiles that represents some object such as `player`, `enemy`, `loot_box`.
  Each `object` should be overlayed on each `landscape` and `over_landscape + landscape` tile.
  Example: enemy stands on bloody snow.

  `ready` - not changable tiles, i.e. tiles that shouldn't overlayed with any other tile.
  Example: water.

  Initial tiles images should be placed in appropriate folder at `priv/tile_images/` dir,
  then after running the module all ready tiles will be placed at `priv/tile_images/tmp/ready`.
  """
  require Logger

  @priv_dir Path.join([File.cwd!(), "priv"])

  @base_dir "/tile_images"

  @over_landscape "/over_landscape"
  @landscape "/landscape"
  @objects "/objects"
  @ready "/ready"

  @tmp_base "/tmp"
  @tmp_dirs_to_create [@landscape, @objects, @ready]

  @allowed_extensions ~w(png gif)

  @spec generate_tiles!(root_dir :: String.t()) :: :ok
  def generate_tiles!(root_dir \\ @priv_dir) do
    prepare_tmp_dirs!(root_dir)

    ready = get_files(root_dir, @ready)
    cp_ready_files(root_dir, ready)

    generate_landscape!(root_dir)
    generate_objects!(root_dir)

    :ok
  end

  defp generate_landscape!(root_dir) do
    over_landscapes = get_files(root_dir, @over_landscape)
    landscapes = get_files(root_dir, @landscape)

    for landscape <- landscapes do
      filename = get_filename(landscape)
      tmp_landscape_path = Path.join([root_dir, @base_dir, @tmp_base, @landscape, filename])
      tmp_ready_path = Path.join([root_dir, @base_dir, @tmp_base, @ready, filename])

      File.cp!(landscape, tmp_landscape_path)
      File.cp!(landscape, tmp_ready_path)

      for over_landscape <- over_landscapes do
        over_landscape_filename = get_filename_without_ext(over_landscape)
        landscape_filename = get_filename_without_ext(landscape)
        filename = "#{over_landscape_filename}_#{landscape_filename}.png"

        {:ok, over_landscape_img} = Image.open(over_landscape)
        {:ok, landscape_img} = Image.open(landscape)

        path = Path.join([root_dir, @base_dir, @tmp_base, @landscape, filename])
        tmp_ready_path = Path.join([root_dir, @base_dir, @tmp_base, @ready, filename])

        Image.compose!(landscape_img, over_landscape_img, x: :middle, y: :middle)
        |> write_image!(path)

        File.cp!(path, tmp_ready_path)
      end
    end
  end

  defp generate_objects!(root_dir) do
    objects = get_files(root_dir, @objects)
    tmp_landscapes = get_tmp_files(root_dir, @landscape)

    for object <- objects do
      for landscape <- tmp_landscapes do
        object_filename = get_filename_without_ext(object)
        landscape_filename = get_filename_without_ext(landscape)
        filename = "#{object_filename}_#{landscape_filename}.png"

        {:ok, object_img} = Image.open(object)
        {:ok, landscape_img} = Image.open(landscape)

        path = Path.join([root_dir, @base_dir, @tmp_base, @ready, filename])

        Image.compose!(landscape_img, object_img, x: :middle, y: :middle)
        |> write_image!(path)
      end
    end
  end

  defp write_image!(image, path) do
    Image.write!(image, path)
    Logger.info("Generated tile #{path}")
  end

  defp prepare_tmp_dirs!(root_dir) do
    base_tmp_path = Path.join([root_dir, @base_dir, @tmp_base])
    File.rm_rf(base_tmp_path)
    File.mkdir!(base_tmp_path)

    for dir_to_create <- @tmp_dirs_to_create do
      path = Path.join([root_dir, @base_dir, @tmp_base, dir_to_create])
      File.rm_rf(path)
      File.mkdir!(path)
    end
  end

  defp get_files(root_dir, directory) do
    Path.join([root_dir, @base_dir, directory])
    |> File.ls!()
    |> Enum.filter(&allowed_ext/1)
    |> Enum.map(fn filename ->
      Path.join([root_dir, @base_dir, directory, filename])
    end)
  end

  defp get_tmp_files(root_dir, directory) do
    Path.join([root_dir, @base_dir, @tmp_base, directory])
    |> File.ls!()
    |> Enum.filter(&allowed_ext/1)
    |> Enum.map(fn filename ->
      Path.join([root_dir, @base_dir, @tmp_base, directory, filename])
    end)
  end

  defp cp_ready_files(root_dir, files) do
    for file <- files do
      filename = get_filename(file)

      path = Path.join([root_dir, @base_dir, @tmp_base, @ready, filename])
      File.cp!(file, path)
    end
  end

  defp allowed_ext(filename) do
    [_, ext] = String.split(filename, ".")
    ext in @allowed_extensions
  end

  defp get_filename(path) do
    path
    |> String.split("/")
    |> List.last()
  end

  defp get_filename_without_ext(path) do
    path
    |> get_filename()
    |> String.split(".")
    |> List.first()
  end
end
