defmodule Europa.Server.Planet.Predefined.Utils.FilesReader do
  @spec parse_files(base_directory :: String.t(), categories :: map()) :: map()
  def parse_files(base_directory, categories) when is_map(categories) do
    priv_dir = :code.priv_dir(:europa)

    Enum.map(categories, fn {category_name, category_attrs} ->
      dir = Map.fetch!(category_attrs, :dir)
      path = Path.join([priv_dir, base_directory, dir])

      {category_name, parse_files!(path)}
    end)
    |> Enum.into(%{})
  end

  defp parse_files!(path) do
    path
    |> File.ls!()
    |> Enum.map(fn filename ->
      path
      |> Path.join(filename)
      |> File.read!()
    end)
  end
end
