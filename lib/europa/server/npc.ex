defmodule Europa.Server.Npc do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Characters.Character

  typedstruct enforce: true do
    field :character, Character.t()
    field :story, Character.story()
    field :stand_on, Planet.tile()
  end

  @spec new(Character.t(), Planet.tile()) :: t()
  def new(%Character{} = character, stand_on) do
    %__MODULE__{
      character: character,
      story: Character.random_story(character),
      stand_on: stand_on
    }
  end

  @spec readable_stats(t()) :: list({String.t(), String.t() | integer()})
  def readable_stats(%__MODULE__{character: character}) do
    [
      {gettext("Name"), character.name},
      {gettext("Age"), character.current_age},
      {gettext("Gender"), Character.readable_gender(character)}
    ]
  end
end
