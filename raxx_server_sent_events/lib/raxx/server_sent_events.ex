defmodule Raxx.ServerSentEvents do
  @moduledoc """
  Upgrade a HTTP connection to send an event stream.
  """
  defmodule Event do
    @moduledoc """
    Create and manipulate individual chunks that comply with the server sent events protocol.
    """
    defstruct [
      id: nil,
      data: "",
      event: nil
    ]

    @doc """
    Create a new event from data and additional options
    """
    @spec new(binary, %{atom => any}) :: %{atom => any} # FIXME Should be an Event.t
    def new(data, opts \\ %{}) do
      struct(%__MODULE__{data: data}, opts)
    end

    @doc """
    Convert an Event struct to a binary chunk that can be sent over the streaming connection.
    """
    def to_chunk(%{data: data, event: event}) do
      event_lines(event) ++ data_lines(data) ++ ["\r\n"]
      |> Enum.join("\r\n")
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
  @doc """
  Creates the upgrade information needed to start communication with SSEs.

  **NOTE:** This is just a `Raxx.Chunked` upgrade object with extra headers to specify the content is an event stream.
  """
  def upgrade(app) do
    # initial = case Map.get(opts, :retry) do
    #   :nil ->
    #     ""
    #   timeout ->
    #     "retry: #{timeout}"
    # end
    Raxx.Chunked.upgrade(app, headers: [{"content-type", "text/event-stream"}])
  end
end
