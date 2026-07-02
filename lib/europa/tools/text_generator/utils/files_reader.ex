defmodule Europa.Tools.TextGenerator.Utils.FilesReader do
  @spec parse_files(directory :: String.t(), templates :: map()) :: map()
  def parse_files(base_directory, templates) do
    priv_dir = :code.priv_dir(:europa)

    Enum.map(templates, fn {template, filename} ->
      path = Path.join([priv_dir, base_directory, filename])

      content =
        path
        |> File.read!()
        |> Jason.decode!()

      {template, content}
    end)
    |> Enum.into(%{})
  end
end
