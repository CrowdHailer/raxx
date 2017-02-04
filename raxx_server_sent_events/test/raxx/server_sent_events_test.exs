defmodule Raxx.ServerSentEventsTest do
  alias Raxx.ServerSentEvents.Event

  use ExUnit.Case

  test "can create chunk with data" do
    chunk = Event.new("boo") |> Event.to_chunk
    assert "data: boo\r\n\r\n" == chunk
  end

  test "can create chunk with multiline data" do
    chunk = Event.new("boo\nyah") |> Event.to_chunk
    assert "data: boo\r\ndata: yah\r\n\r\n" == chunk
  end

  test "can create chunk with only newline data" do
    chunk = Event.new("\n") |> Event.to_chunk
    assert "data: \r\ndata: \r\n\r\n" == chunk
  end

  # FIXME work out what happens to events with new line charachters in string
  test "will send the event with an event type" do
    chunk = Event.new("", %{event: "greeting"}) |> Event.to_chunk
    assert "event: greeting\r\ndata: \r\n\r\n" == chunk
  end
end
