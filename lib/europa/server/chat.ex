defmodule Europa.Server.Chat do
  @moduledoc """
  Game text chat.
  Used for informing user about game actions and stories.
  """

  use TypedStruct

  import Europa.Tools.Conf

  defmodule Message do
    use TypedStruct

    alias Europa.Tools.Types

    @allowed_categories [:story, :regular, :warning, :danger]

    @type category :: unquote(Types.one_of(@allowed_categories))
    @type text :: String.t()

    typedstruct enforce: true do
      field :text, text()
      field :category, category()
    end

    @spec new(text(), category()) :: t()
    def new(text, category) when is_binary(text) and category in @allowed_categories do
      %__MODULE__{
        text: text,
        category: category
      }
    end
  end

  typedstruct enforce: true do
    field :messages, list(Message.t())
  end

  @doc """
  Initializes new chat struct with given `initial_message`.
  """
  @spec new(Message.t()) :: t()
  def new(%Message{} = initial_message) do
    %__MODULE__{
      messages: [initial_message]
    }
  end

  @doc """
  Returns all messages from chat.
  """
  @spec get_all_messages(t()) :: list(Message.t())
  def get_all_messages(%__MODULE__{messages: messages}) do
    messages
  end

  @doc """
  Adds new message to chat.
  New message will replace oldest one if chat messages limit is reached.
  Messages limit should be configured with:

  ```
  config :europa, Server.Chat,
    messages_limit: 100
  ```
  """
  @spec add_message(t(), Message.t()) :: t()
  def add_message(%__MODULE__{messages: messages} = chat, %Message{} = message) do
    updated_messages =
      if Enum.count(messages) == fetch_config!([__MODULE__, :messages_limit]) do
        List.delete_at(messages, 0) ++ [message]
      else
        messages ++ [message]
      end

    struct(chat, messages: updated_messages)
  end
end
