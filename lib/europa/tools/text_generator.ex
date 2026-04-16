defmodule Europa.Tools.TextGenerator do
  alias Europa.Tools.Types
  alias Europa.Tools.FilesCache

  import Europa.Tools.Conf

  @categories [:initial_story, :great_red_spot]
  @default_texts_path "/texts_templates/"

  @filenames %{
    great_red_spot: "story.json"
  }

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

  defp generate_for_category(:great_red_spot, vars) do
    template = parse_file(:great_red_spot)
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

  defp parse_file(category) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, texts_path(), Map.get(@filenames, category)])

    case FilesCache.get(path) do
      {:ok, cached_file} when not is_nil(cached_file) ->
        cached_file

      _ ->
        do_parse_file(path)
    end
  end

  defp do_parse_file(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> tap(fn file_content -> FilesCache.put(path, file_content) end)
  end

  defp texts_path do
    get_config(__MODULE__, []) |> Keyword.get(:texts_path, @default_texts_path)
  end
end
