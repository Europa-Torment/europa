defmodule Europa.Server.Characters do
  use GenServer
  use TypedStruct

  alias Europa.Tools.FilesCache

  @default_filename "characters.json"

  defmodule Character do
    @type gender :: :male | :female

    typedstruct do
      field :name, String.t(), enforce: true
      field :gender, gender(), enforce: true
      field :age_at_disaster, integer(), enforce: true
      field :current_age, integer()
      field :years, list(integer()), enforce: true
      field :stories, list(String.t()), enforce: true
    end

    @spec from_map!(map()) :: t()
    def from_map!(%{} = raw_character) do
      %Character{
        name: Map.fetch!(raw_character, "name"),
        gender: Map.fetch!(raw_character, "gender") |> gender_to_atom(),
        age_at_disaster: Map.fetch!(raw_character, "age_at_disaster"),
        years: Map.fetch!(raw_character, "years") |> parse_years(),
        stories: Map.fetch!(raw_character, "stories"),
        # will be determined later
        current_age: 0
      }
    end

    @spec determine_current_age(t(), current_year_after_disaster :: pos_integer()) :: t()
    def determine_current_age(%__MODULE__{} = character, current_year_after_disaster) do
      struct!(character, current_age: character.age_at_disaster + current_year_after_disaster)
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
    main_character = Character.determine_current_age(main_character, current_year_after_disaster)

    filtered_characters =
      characters
      |> List.delete(main_character)
      |> contemporaries(main_character, current_year_after_disaster)

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
