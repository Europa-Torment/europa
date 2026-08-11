defmodule Europa.Server.Player.Diseases do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Player.Diseases.Disease
  alias Europa.Server.Player.Diseases.Utils.FilesReader

  import Europa.Tools.Conf

  @filename fetch_config!([__MODULE__, :filename])
  @diseases FilesReader.parse_file(@filename) |> Enum.map(&Disease.from_map/1)

  for {disease, i} <- Enum.with_index(@diseases) do
    fun_name = String.to_atom("__extract_strings_for_#{i}")

    def unquote(fun_name)() do
      gettext(unquote(disease.name))
    end
  end

  @spec diseases() :: list(Disease.t())
  def diseases do
    @diseases
  end

  @spec get_by_id(Disease.id()) :: Disease.t() | no_return()
  def get_by_id(id) when is_atom(id) do
    case Enum.find(@diseases, &(&1.id == id)) do
      nil -> raise "no disease with id #{id}"
      disease -> disease
    end
  end
end
