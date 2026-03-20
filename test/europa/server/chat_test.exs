defmodule Europa.Server.Chat.MessageTest do
  use ExUnit.Case, async: true

  alias Europa.Server.Chat.Message

  describe "new/2" do
    test "builds message" do
      text = "Hello"
      category = :story

      assert Message.new(text, category) == %Message{text: text, category: category}
    end
  end
end

defmodule Europa.Server.ChatTest do
  use Europa.DataCase

  alias Europa.Server.Chat

  import Europa.Tools.Conf

  @messages_limit fetch_config!([Chat, :messages_limit])

  setup do
    chat = build(:chat, messages: [])
    message = build(:chat_message)

    {:ok, chat: chat, message: message}
  end

  describe "new/1" do
    test "builds chat with initial message", %{message: message} do
      assert Chat.new(message) == %Chat{messages: [struct!(message, id: 1)], last_id: 1}
    end
  end

  describe "add_message/2" do
    test "adds given message to chat", %{chat: chat, message: message} do
      assert Chat.add_message(chat, message) == %Chat{messages: [struct!(message, id: 1)], last_id: chat.last_id + 1}
    end

    test "replaces oldest message with new message when messages limit reached", %{
      chat: chat,
      message: message
    } do
      messages = build_list(@messages_limit, :chat_message)

      updated_chat =
        Enum.reduce(messages, chat, fn message, chat -> Chat.add_message(chat, message) end)

      first_message = List.first(updated_chat.messages)

      assert Enum.count(updated_chat.messages) == @messages_limit

      updated_chat = Chat.add_message(updated_chat, message)

      message_text = message.text
      message_category = message.category

      assert %Chat.Message{text: ^message_text, category: ^message_category} = List.last(updated_chat.messages)
      assert Enum.count(updated_chat.messages) == @messages_limit

      refute Enum.any?(updated_chat.messages, &(&1 == first_message))
    end
  end

  describe "get_all_messages/1" do
    setup do
      chat = build(:chat, messages: build_list(5, :chat_message))
      {:ok, chat: chat}
    end

    test "returns all messages", %{chat: chat} do
      assert Chat.get_all_messages(chat) == chat.messages
    end
  end
end
