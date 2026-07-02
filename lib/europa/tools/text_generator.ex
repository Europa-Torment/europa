defmodule Europa.Tools.TextGenerator do
  alias Europa.Tools.Types
  alias Europa.Tools.TextGenerator.Utils.FilesReader

  import Europa.Tools.Conf

  @texts_path fetch_config!([__MODULE__, :texts_path])

  @templates %{
    great_red_spot: "story.json"
  }

  @categories Map.keys(@templates)

  @templates FilesReader.parse_files(@texts_path, @templates)

  @type category :: unquote(Types.one_of(@categories))
  @type vars :: keyword()
  @type text() :: String.t()

  @doc """
  Generates text from texts template.
  """
  @spec generate_text(category(), vars()) :: text()
  def generate_text(category, vars) when category in @categories and is_list(vars) do
    generate_for_category(category, vars)
  end

  defp generate_for_category(:great_red_spot = category, vars) do
    template = Map.fetch!(@templates, category)
    get_text(template, "great_red_spot", vars)
  end

  defp get_text(template, text_name, vars) do
    template
    |> Map.get(text_name)
    |> do_get_text(vars)
  end

  defp do_get_text(%{"type" => "random", "texts" => texts}, vars) do
    text = Enum.random(texts)
    EEx.eval_string(text, vars)
  end
end
