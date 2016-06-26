defmodule Raxx.ServerSentEvents do
  defmodule Event do
    defstruct [
      id: nil,
      data: "",
      event: nil
    ]
  end
  def upgrade(options, handler) do
    %{
      upgrade: __MODULE__,
      handler: handler,
      options: options
    }
  end

  def no_event do
    # Annoyingly needs nil checking but there is no native option type in elixir
    :nil
  end

  def event(data) when is_binary(data) do
    %{event: nil, data: data}
  end
  def event(valid =%{event: _type, data: _data}) do
    valid
  end

  # FIXME call event to chunk and use Streaming functionality
  # Does streaming stop by sending empy chunk
  def event_to_string(%{data: ""}) do
    ""
  end
  def event_to_string(%{event: nil, data: data}) do
    "data: #{data}\n\n"
  end
  def event_to_string(%{event: event, data: data}) do
    "event: #{event}\ndata: #{data}\n\n"
  end

  def close() do
    %Event{}
  end
end
