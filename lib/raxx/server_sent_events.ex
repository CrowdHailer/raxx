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
  # TODO test
  def upgrade(mod, env, opts) do
    initial = case Map.get(opts, :retry) do
      :nil ->
        ""
      timeout ->
        "retry: #{timeout}"
    end
    Raxx.Streaming.upgrade(mod, env, %{initial: initial, headers: %{
      "Connection" => "keep-alive",
      "Content-Type" => "text/event-stream",
      "Transfer-Encoding" => "chunked"
    }})
  end
end
