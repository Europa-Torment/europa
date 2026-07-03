defmodule Europa.Server.Loot.Utils.FilesReader do
  @items_templates_path "/items/"
  @item_boxes_templates_path "/item_boxes/"

  @spec parse_items_files(files :: map()) :: map()
  def parse_items_files(files) when is_map(files) do
    priv_dir = :code.priv_dir(:europa)

    Enum.map(files, fn {category, filename} ->
      content =
        Path.join([priv_dir, @items_templates_path, filename])
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
        |> Enum.map(fn attrs -> {attrs, attrs.random_weight} end)

      {category, content}
    end)
    |> Enum.into(%{})
  end

  @spec parse_item_boxes_file(filename :: String.t()) :: list({map(), random_weight :: number()})
  def parse_item_boxes_file(filename) do
    priv_dir = :code.priv_dir(:europa)

    Path.join([priv_dir, @item_boxes_templates_path, filename])
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
    |> Enum.map(fn attrs ->
      {attrs, Map.fetch!(attrs, :random_weight)}
    end)
  end
end
