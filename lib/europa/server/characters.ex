defmodule Europa.Server.Characters do
  use GenServer
  use TypedStruct

  alias Europa.Tools.FilesCache

  @default_filename "characters.json"

  defmodule Character do
    use Gettext, backend: Europa.Gettext

    @type gender :: :male | :female

    @type story :: String.t()
    @type stories :: list(story())
    @type special_stories :: %{optional(String.t()) => stories()}

    @type short_phrase :: String.t()
    @type short_phrases :: list(short_phrase())

    typedstruct do
      field :name, String.t(), enforce: true
      field :gender, gender(), enforce: true
      field :profession, String.t(), enforce: true
      field :age_at_disaster, integer(), enforce: true
      field :current_age, integer()
      field :years, Range.t(), enforce: true
      field :stories, stories(), enforce: true
      field :special_stories, special_stories(), enforce: true
      field :short_phrases, short_phrases(), enforce: true
    end

    @spec from_map!(map()) :: t()
    def from_map!(%{} = raw_character) do
      %Character{
        name: Map.fetch!(raw_character, "name"),
        gender: Map.fetch!(raw_character, "gender") |> gender_to_atom(),
        profession: Map.fetch!(raw_character, "profession"),
        age_at_disaster: Map.fetch!(raw_character, "age_at_disaster"),
        years: Map.fetch!(raw_character, "years") |> parse_years(),
        stories: Map.fetch!(raw_character, "stories"),
        special_stories: Map.get(raw_character, "special_stories", %{}),
        short_phrases: Map.get(raw_character, "short_phrases", []),
        # will be determined later
        current_age: 0
      }
    end

    @spec determine_current_age(t(), current_year_after_disaster :: pos_integer()) :: t()
    def determine_current_age(%__MODULE__{} = character, current_year_after_disaster) do
      struct!(character, current_age: character.age_at_disaster + current_year_after_disaster)
    end

    @spec readable_gender(t()) :: String.t()
    def readable_gender(%__MODULE__{gender: gender}) do
      case gender do
        :male -> gettext("Male")
        :female -> gettext("Female")
      end
    end

    @spec random_story(t()) :: story()
    def random_story(%__MODULE__{stories: stories}) do
      Enum.random(stories)
    end

    @spec random_special_story(character :: t(), main_character :: t()) :: story() | nil
    def random_special_story(character, main_character) do
      case Map.get(character.special_stories, main_character.name) do
        [] -> nil
        special_stories when is_list(special_stories) -> Enum.random(special_stories)
        _ -> nil
      end
    end

    @spec short_phrase(t()) :: short_phrase() | nil
    def short_phrase(%__MODULE__{short_phrases: []}), do: nil

    def short_phrase(%__MODULE__{short_phrases: phrases}) do
      Enum.random(phrases)
    end

    defp parse_years(%{"from" => from, "to" => to}) when is_integer(from) and is_integer(to) and from < to do
      from..to
    end

    defp gender_to_atom("male"), do: :male
    defp gender_to_atom("female"), do: :female
  end

  typedstruct module: State, enforce: true do
    field :characters, list(Character.t())
    field :main_character_picked?, boolean(), default: false
  end

  ### PUBLIC INTERFACE ###

  @spec start_link(filename :: String.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(filename \\ @default_filename) do
    GenServer.start_link(__MODULE__, filename)
  end

  @spec pick_main(pid()) :: {:ok, Character.t()} | {:error, :already_picked}
  def pick_main(pid) do
    GenServer.call(pid, :pick_main)
  end

  @spec pick(pid(), current_year_after_disaster :: pos_integer()) :: {:ok, Character.t()} | {:error, :no_characters}
  def pick(pid, current_year_after_disaster) do
    GenServer.call(pid, {:pick, current_year_after_disaster})
  end

  ### CALLBACKS ###

  @impl true
  def init(filename) do
    state = %State{main_character_picked?: false, characters: initial_characters(filename)}
    {:ok, state}
  end

  @impl true
  def handle_call(:pick_main, _from, %State{main_character_picked?: true} = state) do
    {:reply, {:error, :already_picked}, state}
  end

  def handle_call(:pick_main, _from, %State{characters: characters} = state) do
    main_character = Enum.random(characters)
    current_year_after_disaster = Enum.random(main_character.years)

    filtered_characters =
      characters
      |> List.delete(main_character)
      |> contemporaries(main_character, current_year_after_disaster)

    main_character = Character.determine_current_age(main_character, current_year_after_disaster)
    {:reply, {:ok, main_character}, struct!(state, characters: filtered_characters, main_character_picked?: true)}
  end

  def handle_call({:pick, current_year_after_disaster}, _from, %State{characters: characters} = state) do
    case do_pick(characters, current_year_after_disaster) do
      {:ok, {character, rest_characters}} ->
        {:reply, {:ok, character}, struct!(state, characters: rest_characters)}

      error ->
        {:reply, error, state}
    end
  end

  ### PRIVATE ###

  defp do_pick(characters, current_year_after_disaster) do
    case Enum.filter(characters, fn character -> current_year_after_disaster in character.years end) do
      [] ->
        {:error, :no_characters}

      characters ->
        character = Enum.random(characters)
        rest_characters = List.delete(characters, character)
        {:ok, {Character.determine_current_age(character, current_year_after_disaster), rest_characters}}
    end
  end

  defp contemporaries(characters, main_character, current_year_after_disaster) do
    Enum.filter(characters, fn character ->
      # only adult characters
      live_in_same_years?(main_character, character) && current_year_after_disaster + character.age_at_disaster > 15
    end)
  end

  defp live_in_same_years?(first_character, second_character) do
    first_years = MapSet.new(first_character.years)
    second_years = MapSet.new(second_character.years)

    MapSet.intersection(first_years, second_years) |> MapSet.to_list() != []
  end

  defp initial_characters(filename) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, "characters", filename])

    case FilesCache.get(path) do
      {:ok, file_content} ->
        file_content

      _ ->
        path
        |> File.read!()
    end
    |> parse_characters()
  end

  defp parse_characters(raw_characters) do
    raw_characters
    |> Jason.decode!()
    |> Enum.map(fn raw_character ->
      Character.from_map!(raw_character)
    end)
  end
end
