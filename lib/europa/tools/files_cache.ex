defmodule Europa.Tools.FilesCache do
  @cache_name :files

  @type file_content :: map() | list()

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_args \\ []) do
    Supervisor.child_spec({Cachex, @cache_name}, id: @cache_name)
  end

  @spec get(path :: String.t()) :: {:ok, file_content()} | {:error, :no_cache}
  def get(path) when is_binary(path) do
    case Cachex.get(@cache_name, path) do
      {:ok, file_content} when not is_nil(file_content) ->
        {:ok, file_content}

      _ ->
        {:error, :no_cache}
    end
  end

  @spec put(path :: String.t(), file_content()) :: :ok | {:error, :cache_error}
  def put(path, file_content)
      when (is_binary(path) and is_map(file_content)) or is_list(file_content) or is_binary(file_content) do
    case Cachex.put(@cache_name, path, file_content) do
      {:ok, true} ->
        :ok

      _ ->
        {:error, :cache_error}
    end
  end
end
