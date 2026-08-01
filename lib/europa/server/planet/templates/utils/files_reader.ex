defmodule Europa.Server.Planet.Templates.Utils.FilesReader do
  @spec parse_files(base_directory :: String.t(), categories :: map()) :: map()
  def parse_files(base_directory, categories) when is_map(categories) do
    priv_dir = :code.priv_dir(:europa)

    Enum.map(categories, fn {category_name, category_attrs} ->
      dir = Map.fetch!(category_attrs, :dir)
      path = Path.join([priv_dir, base_directory, dir])

      {category_name, parse_directory_with_subdirs!(path)}
    end)
    |> Enum.into(%{})
  end

  defp parse_directory_with_subdirs!(path) do
    entries = File.ls!(path)

    {files, dirs} =
      Enum.split_with(entries, fn entry ->
        path = Path.join(path, entry)
        not File.dir?(path)
      end)

    base_templates =
      files
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(fn file ->
        path
        |> Path.join(file)
        |> parse_template()
      end)

    subdirs =
      Enum.reduce(dirs, %{}, fn dir_name, acc ->
        dir_path = Path.join(path, dir_name)

        templates =
          dir_path
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.map(fn file ->
            dir_path
            |> Path.join(file)
            |> parse_template()
          end)

        Map.put(acc, dir_name, templates)
      end)

    Map.put(subdirs, "base_templates", base_templates)
  end

  defp parse_template(path) do
    attrs = File.read!(path) |> Jason.decode!(keys: :atoms)
    random_weight = Map.fetch!(attrs, :random_weight)

    {attrs, random_weight}
  end
end
