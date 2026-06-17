defmodule Europa.Server.Loot.Utils.FilesReader do
  @templates_path "/items/"

  @spec parse_files(files :: map()) :: map()
  def parse_files(files) when is_map(files) do
    priv_dir = :code.priv_dir(:europa)

    Enum.map(files, fn {category, filename} ->
      content =
        Path.join([priv_dir, @templates_path, filename])
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
        |> Enum.map(fn attrs -> {attrs, attrs.random_weight} end)

      {category, content}
    end)
    |> Enum.into(%{})
  end
end
