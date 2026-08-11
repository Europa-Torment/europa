defmodule Europa.Server.Action do
  use TypedStruct

  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Planet.Storm
  alias Europa.Server.Player.Diseases.Disease

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
          | {:temperature, temperature :: integer()}
          | {:storm, Storm.t()}
          | {:healed, healed_enemy :: Enemy.t(), heal_unit :: pos_integer()}
          | {:disease, Disease.id()}
          | {:recovered_disease, Disease.id()}
          | :diseases_damage

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
