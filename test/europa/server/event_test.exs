defmodule Europa.Server.EventTest do
  use Europa.DataCase

  alias Europa.Server.Event

  describe "new/1" do
    test "retunrs event struct" do
      type = :interested
      assert %Event{type: ^type} = Event.new(type)
    end
  end

  describe "stack_events/1" do
    test "stacks stackable events" do
      event1 = build(:event, type: {:damaged, 10})
      event2 = build(:event, type: {:damaged, 20})
      event3 = build(:event, type: {:healed, 30})
      event4 = build(:event, type: :interested)

      events = Event.stack_events([event1, event2, event3, event4])

      assert Enum.count(events) == 3

      assert Enum.find(events, fn
               %Event{type: {:damaged, 30}} -> true
               _ -> false
             end)

      assert Enum.find(events, fn
               %Event{type: {:healed, 30}} -> true
               _ -> false
             end)

      assert Enum.find(events, fn
               %Event{type: :interested} -> true
               _ -> false
             end)
    end
  end
end
