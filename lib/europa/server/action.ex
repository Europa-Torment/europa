defmodule Europa.Server.Action do
  use TypedStruct

  alias Europa.Server.Enemy
  alias Europa.Server.Npc

  @type subject :: Enemy.t() | :player | {Enemy.t(), Npc.t()} | {Npc.t(), Enemy.t() | Npc.t()} | Npc.t()

  @type action_type ::
          :attack
          | :miss_attack
          | :chasing
          | :stay
          | :get_cold
          | :frostbite
          | :dehydration
          | :radiation_contamination
          | :radiation_damage
          | :hunger
          | :warm_up
          | {:healed, healed_enemy :: Enemy.t(), heal_unit :: pos_integer()}

  typedstruct enforce: true do
    field :subject, subject()
    field :action_type, action_type()
  end

  @spec new(subject(), action_type()) :: t()
  def new(subject, action_type) do
    %__MODULE__{
      subject: subject,
      action_type: action_type
    }
  end
end
