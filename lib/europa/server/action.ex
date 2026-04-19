defmodule Europa.Server.Action do
  use TypedStruct

  alias Europa.Tools.Types
  alias Europa.Server.Enemy
  alias Europa.Server.Npc

  @allowed_action_types [
    :attack,
    :miss_attack,
    :chasing,
    :stay,
    :get_cold,
    :frostbite,
    :dehydration,
    :radiation_contamination,
    :radiation_damage,
    :hunger,
    :warm_up,
    :enemy_killed_npc
  ]

  @type subject :: Enemy.t() | :player | {Enemy.t(), Npc.t()}
  @type action_type :: unquote(Types.one_of(@allowed_action_types))

  typedstruct enforce: true do
    field :subject, subject()
    field :action_type, action_type()
  end

  @spec new(subject(), action_type()) :: t()
  def new(subject, action_type) when action_type in @allowed_action_types do
    %__MODULE__{
      subject: subject,
      action_type: action_type
    }
  end
end
