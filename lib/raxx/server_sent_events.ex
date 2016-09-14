defmodule Raxx.ServerSentEvents do
  defmodule Event do
    defstruct [
      id: nil,
      data: "",
      event: nil
    ]

    def new(data, opts \\ %{}) do
      struct(%__MODULE__{data: data}, opts)
    end

    def to_chunk(%{data: data, event: event}) do
      event_lines(event) ++ data_lines(data) ++ ["\n"]
      |> Enum.join("\n")
    end

    defp event_lines(nil) do
      []
    end
    defp event_lines(event) do
      ["event: #{event}"]
    end

    defp data_lines(data) do
      String.split(data, "\n")
      |> Enum.map(fn (line) -> "data: #{line}" end)
    end
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
