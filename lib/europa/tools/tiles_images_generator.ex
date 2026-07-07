defmodule Europa.Tools.TilesImagesGenerator do
  @moduledoc """
  Tiles images generator.
  Makes artists' work easier: automates the creation of tiles images by overlaying them on top of each other.

  There are 4 types of tiles:

  `landscape` - ladndscape tiles such as snow, water, ice, etc

  `over_landscape` - tiles that should be overlayed on `landscape` tiles, example: bloody versions of each landscape tile

  `objects` - tiles that represents some object such as `player`, `wall`.
  Each `object` should be overlayed on each `landscape` (and overlayed `landscape`).
  Example: "enemy stands on bloody snow" or "player stands on monster body stands on snow".

  `enemies` - tiles that represents enemies. Files will be copied to `objects`.

  `loot` - tiles that represents loot item boxes. Files will be copied to `objects`.

  `ready` - not changeable tiles, i.e. tiles that shouldn't overlayed with any other tile.
  Example: water.

  Initial tiles images should be placed in appropriate folder at `priv/tile_images/` dir,
  then after running the module all ready tiles will be placed at `priv/tile_images/tmp/ready`.
  """
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Loot

  require Logger

  @priv_dir Path.join([File.cwd!(), "priv"])

  @base_dir "/tile_images"

  @over_landscape "/over_landscape"
  @landscape "/landscape"
  @objects "/objects"
  @enemies "/enemies"
  @loot "/loot"
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
    # copy base landscape tiles to tmp dir
    for landscape <- get_files(root_dir, @landscape) do
      filename = get_filename(landscape)
      tmp_landscape_path = Path.join([root_dir, @base_dir, @tmp_base, @landscape, filename])

      File.cp!(landscape, tmp_landscape_path)
    end

    files = [
      get_files(root_dir, @over_landscape),
      get_movable_object_files(root_dir),
      get_movable_loot_files(root_dir)
    ]

    generate_landscape!(root_dir, files)
  end

  defp generate_landscape!(root_dir, []) do
    tmp_landscapes = Path.join([@tmp_base, @landscape])

    for landscape <- get_files(root_dir, tmp_landscapes) do
      ready_path = Path.join([root_dir, @base_dir, @tmp_base, @ready, get_filename(landscape)])
      File.cp!(landscape, ready_path)
    end
  end

  defp generate_landscape!(root_dir, [files | rest]) do
    tmp_landscapes = Path.join([@tmp_base, @landscape])

    for landscape <- get_files(root_dir, tmp_landscapes) do
      for over_landscape <- files do
        do_generate_landscape(root_dir, landscape, over_landscape)
      end
    end

    generate_landscape!(root_dir, rest)
  end

  defp do_generate_landscape(root_dir, landscape, over_landscape) do
    over_landscape_filename = get_filename_without_ext(over_landscape)
    landscape_filename = get_filename_without_ext(landscape)

    if get_ext(landscape) == "gif" do
      filename = "#{over_landscape_filename}_#{landscape_filename}.gif"
      path = Path.join([root_dir, @base_dir, @tmp_base, @landscape, filename])
      write_gif(landscape, over_landscape, path)
    else
      filename = "#{over_landscape_filename}_#{landscape_filename}.png"
      path = Path.join([root_dir, @base_dir, @tmp_base, @landscape, filename])
      write_png(landscape, over_landscape, path)
    end
  end

  defp get_movable_loot_files(root_dir) do
    movable_loot =
      Loot.movable_item_box_types()
      |> Enum.map(&Loot.item_box_image/1)

    get_files(root_dir, @loot)
    |> Enum.filter(fn loot -> get_filename_without_ext(loot) in movable_loot end)
  end

  defp get_not_movable_loot_files(root_dir) do
    movable_loot =
      Loot.movable_item_box_types()
      |> Enum.map(&Loot.item_box_image/1)

    get_files(root_dir, @loot)
    |> Enum.filter(fn loot -> get_filename_without_ext(loot) not in movable_loot end)
  end

  defp get_movable_object_files(root_dir) do
    movable_objects =
      Objects.objects()
      |> Enum.filter(fn {_, object} -> object.movable? end)
      |> Enum.map(fn {_, object} -> object.image_name end)

    get_files(root_dir, @objects)
    |> Enum.filter(fn object -> get_filename_without_ext(object) in movable_objects end)
  end

  defp get_not_movable_object_files(root_dir) do
    movable_objects =
      Objects.objects()
      |> Enum.filter(fn {_, object} -> object.movable? end)
      |> Enum.map(fn {_, object} -> object.image_name end)

    get_files(root_dir, @objects)
    |> Enum.filter(fn object -> get_filename_without_ext(object) not in movable_objects end)
  end

  defp generate_objects!(root_dir) do
    objects =
      get_not_movable_object_files(root_dir) ++ get_files(root_dir, @enemies) ++ get_not_movable_loot_files(root_dir)

    tmp_landscapes = get_tmp_files(root_dir, @landscape)

    for object <- objects do
      for landscape <- tmp_landscapes do
        do_generate_object(root_dir, landscape, object)
      end
    end
  end

  defp do_generate_object(root_dir, landscape, object) do
    object_filename = get_filename_without_ext(object)
    landscape_filename = get_filename_without_ext(landscape)
    ext = ext_for_list([object, landscape])
    filename = "#{object_filename}_#{landscape_filename}.#{ext}"

    path = Path.join([root_dir, @base_dir, @tmp_base, @ready, filename])

    if get_ext(object) == "gif" do
      write_gif(landscape, object, path)
    else
      write_png(landscape, object, path)
    end
  end

  defp write_gif(first, second, path) do
    second_looping? = gif_loops_forever?(second)

    {:ok, first_img} = Image.open(first)
    {:ok, second_img} = Image.open(second, pages: :all)

    total_height = Image.height(second_img)
    pages_count = Image.pages(second_img)
    single_frame_height = div(total_height, pages_count)

    {:ok, result} =
      Image.map_join_pages(second_img, fn frame ->
        Image.compose(first_img, frame, mode: :over)
      end)

    {:ok, result} =
      Vix.Vips.Image.mutate(result, fn mut_img ->
        :ok = Vix.Vips.MutableImage.set(mut_img, "page-height", :gint, single_frame_height)

        loop_count = if second_looping?, do: 0, else: 1
        :ok = Vix.Vips.MutableImage.set(mut_img, "loop", :gint, loop_count)
      end)

    write_image!(result, path)
  end

  defp gif_loops_forever?(path) do
    {:ok, binary} = File.read(path)

    case :binary.split(binary, "NETSCAPE2.0") do
      [_before, <<3, 1, 0, 0, _rest::binary>>] ->
        true

      [_before, <<3, 1, loop_count::16-little, _rest::binary>>] when loop_count > 0 ->
        false

      _ ->
        false
    end
  end

  defp write_png(first, second, path) do
    {:ok, second_img} = Image.open(second)
    {:ok, first_img} = Image.open(first)

    Image.compose!(first_img, second_img, x: :middle, y: :middle)
    |> write_image!(path)
  end

  defp write_image!(image, path, opts \\ []) do
    Image.write!(image, path, opts)
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
    ext = get_ext(filename)
    ext in @allowed_extensions
  end

  defp get_ext(filename) do
    filename
    |> String.split(".")
    |> List.last()
  end

  defp ext_for_list(filenames) when is_list(filenames) do
    if Enum.any?(filenames, fn filename -> get_ext(filename) == "gif" end) do
      "gif"
    else
      "png"
    end
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
