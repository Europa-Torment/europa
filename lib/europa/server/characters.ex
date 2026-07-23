defmodule Europa.Server.Characters do
  use GenServer
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Characters.Utils.FilesReader

  import Europa.Tools.Conf

  @filename fetch_config!([__MODULE__, :filename])
  @raw_characters FilesReader.parse_file(@filename)

  for {character, i} <- Enum.with_index(@raw_characters) do
    fun_name = String.to_atom("__extract_strings_for_#{i}")

    def unquote(fun_name)() do
      gettext(unquote(character["name"]))
      gettext(unquote(character["profession"]))

      unquote_splicing(
        for phrase <- Map.get(character, "short_phrases", []) do
          quote do
            gettext(unquote(phrase))
          end
        end
      )

      unquote_splicing(
        for story <- Map.get(character, "stories", []) do
          quote do
            gettext(unquote(story))
          end
        end
      )

      unquote_splicing(
        for {_, stories} <- Map.get(character, "special_stories", []) do
          for story <- stories do
            quote do
              gettext(unquote(story))
            end
          end
        end
      )
    end
  end

  defmodule Character do
    use Gettext, backend: Europa.Gettext

    @type gender :: :male | :female

    @type story :: String.t()
    @type stories :: list(story())
    @type special_stories :: %{optional(String.t()) => stories()}

    @type short_phrase :: String.t()
    @type short_phrases :: list(short_phrase())

    @type fraction :: :neutral | :wcc | :ssb | :etc

    typedstruct do
      field :name, String.t(), enforce: true
      field :gender, gender(), enforce: true
      field :profession, String.t(), enforce: true
      field :fraction, fraction(), enforce: true
      field :enemy_fractions, list(fraction()), enforce: true, default: []
      field :age_at_disaster, integer(), enforce: true
      field :current_age, integer()
      field :years, Range.t(), enforce: true
      field :stories, stories(), enforce: true
      field :special_stories, special_stories(), enforce: true
      field :short_phrases, short_phrases(), enforce: true
      field :not_playable?, boolean(), enforce: true, default: false
    end

    @spec from_map!(map()) :: t()
    def from_map!(%{} = raw_character) do
      %Character{
        name: Map.fetch!(raw_character, "name"),
        gender: Map.fetch!(raw_character, "gender") |> String.to_atom(),
        profession: Map.fetch!(raw_character, "profession"),
        fraction: Map.fetch!(raw_character, "fraction") |> String.to_atom(),
        enemy_fractions: Map.get(raw_character, "enemy_fractions", []) |> Enum.map(&String.to_atom/1),
        age_at_disaster: Map.fetch!(raw_character, "age_at_disaster"),
        years: Map.fetch!(raw_character, "years") |> parse_years(),
        stories: Map.fetch!(raw_character, "stories"),
        special_stories: Map.get(raw_character, "special_stories", %{}),
        short_phrases: Map.get(raw_character, "short_phrases", []),
        not_playable?: Map.get(raw_character, "not_playable", false),
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

    @spec readable_fraction(t()) :: String.t()
    def readable_fraction(%__MODULE__{fraction: fraction}) do
      case fraction do
        :ssb -> gettext("SSB")
        :wcc -> gettext("WCC")
        :etc -> gettext("ETC")
        :neutral -> gettext("Neutral")
      end
    end

    @spec random_story(t()) :: story()
    def random_story(%__MODULE__{not_playable?: true}), do: nil

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
  end

  typedstruct module: State, enforce: true do
    field :characters, list(Character.t())
    field :main_character_picked?, boolean(), default: false
  end

  ### PUBLIC INTERFACE ###

  @spec start_link() :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  @spec enemies?(Character.t(), Character.t()) :: boolean()
  def enemies?(%Character{} = first_character, %Character{} = second_character) do
    first_enemy? = first_character.fraction in second_character.enemy_fractions
    second_enemy? = second_character.fraction in first_character.enemy_fractions

    first_enemy? || second_enemy?
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
  def init(_args) do
    init_characters = Enum.map(@raw_characters, &Character.from_map!/1)
    state = %State{main_character_picked?: false, characters: init_characters}
    {:ok, state}
  end

  @impl true
  def handle_call(:pick_main, _from, %State{main_character_picked?: true} = state) do
    {:reply, {:error, :already_picked}, state}
  end

  def handle_call(:pick_main, _from, %State{characters: characters} = state) do
    main_character =
      characters
      |> Enum.filter(fn character -> not character.not_playable? end)
      |> Enum.random()

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

        rest_characters =
          if character.not_playable? do
            characters
          else
            List.delete(characters, character)
          end

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
end
