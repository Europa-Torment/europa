defmodule Europa.Server.Action do
  use TypedStruct

  alias Europa.Tools.Types
  alias Europa.Server.Enemy

  @allowed_action_types [:attack, :miss_attack, :chasing, :stay, :get_cold, :frostbite, :dehydration, :hunger, :warm_up]

  @type subject :: Enemy.t() | :player
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
