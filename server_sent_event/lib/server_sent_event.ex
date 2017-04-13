defmodule ServerSentEvent do
  @moduledoc """
  To enable servers to push data to Web pages over HTTP or using dedicated server-push protocols.

  Messages are sent in the following form, with the `text/event-stream` MIME type:

  ```sh
  data: This is the first message.

  data: This is the second message, it
  data: has two lines.

  event: custom
  data: This message has event type 'custom'.

  ```

  A living standard is available from [WHATWG](https://html.spec.whatwg.org/#server-sent-events).

  The contents of a server-sent-event are:

  | **type** | The type of an event |
  | **lines** | The data contents of the event split by line |
  | **id** | Value to send in `last-event-id` header when reconnecting |
  | **retry** | Time to wait before retrying connection in milliseconds |
  | **comments** | Any lines from original block that were marked as comments |
  """

  @new_line ~r/\R/

  defstruct [
    type: nil,
    lines: [],
    id: nil,
    retry: nil,
    comments: []
  ]

  @doc """
  This event stream format's MIME type is `text/event-stream`.
  """
  def mime_type do
    "text/event-stream"
  end

  @doc """
  Does the event have any data lines.

  An event without any data lines will not trigger any browser events.
  """
  def empty?(%{lines: []}), do: true
  def empty?(%{lines: _}), do: false

  @doc """
  Format an event to be sent as part of a stream

  **NOTE:** Each data/comment line must be without new line charachters.

  ## Examples
  *In these examples this module has been aliased to `SSE`*.

      iex> %SSE{type: "greeting", lines: ["Hi,", "there"], comments: ["comment"]}
      ...> |> SSE.serialize()
      "event: greeting\\n: comment\\ndata: Hi,\\ndata: there"

      iex> %SSE{lines: ["message with id"], id: "some-id"}
      ...> |> SSE.serialize()
      "data: message with id\\nid: some-id"

      iex> %SSE{lines: ["message setting retry to 10s"], retry: 10_000}
      ...> |> SSE.serialize()
      "data: message setting retry to 10s\\nretry: 10000"
  """
  def serialize(event = %__MODULE__{}) do
    type_line(event)
    ++ comment_lines(event)
    ++ data_lines(event)
    ++ id_line(event)
    ++ retry_line(event)
    |> Enum.join("\n")
  end

  defp type_line(%{type: nil}) do
    []
  end
  defp type_line(%{type: type}) do
    single_line?(type) || raise "Bad"
    ["event: " <> type]
  end

  defp comment_lines(%{comments: comments}) do
    Enum.map(comments, fn(comment) ->
      single_line?(comment) || raise "Bad"
      ": " <> comment
    end)
  end

  defp data_lines(%{lines: lines}) do
    Enum.map(lines, fn(line) ->
      single_line?(line) || raise "Bad"
      "data: " <> line
    end)
  end

  defp id_line(%{id: nil}) do
    []
  end
  defp id_line(%{id: id}) do
    single_line?(id) || raise "Bad"
    ["id: " <> id]
  end

  defp retry_line(%{retry: nil}) do
    []
  end
  defp retry_line(%{retry: retry}) when is_integer(retry) do
    ["retry: " <> to_string(retry)]
  end

  defp single_line?(text) do
    length(String.split(text, @new_line, parts: 2)) == 1
  end

  @doc """
  Parse the next event from text stream, if present.

  ## Examples
  *In these examples this module has been aliased to `SSE`*.

      iex> SSE.parse("data: This is the first message\\n\\n")
      {%SSE{lines: ["This is the first message"]}, ""}

      iex> SSE.parse("data:First whitespace character is optional\\n\\n")
      {%SSE{lines: ["First whitespace character is optional"]}, ""}

      iex> SSE.parse("data: This message\\ndata: has two lines.\\n\\n")
      {%SSE{lines: ["This message", "has two lines."]}, ""}

      iex> SSE.parse("data: This message is not complete")
      nil

      iex> SSE.parse("event: custom\\ndata: This message is type custom\\n\\n")
      {%SSE{type: "custom", lines: ["This message is type custom"]}, ""}

      iex> SSE.parse("id: 100\\ndata: This message has an id\\n\\n")
      {%SSE{id: "100", lines: ["This message has an id"]}, ""}

      iex> SSE.parse("retry: 5000\\ndata: This message retries after 5s.\\n\\n")
      {%SSE{retry: 5000, lines: ["This message retries after 5s."]}, ""}

      iex> SSE.parse(": This is a comment\\n\\n")
      {%SSE{comments: ["This is a comment"]}, ""}

      iex> SSE.parse("data: data can have more :'s in it'\\n\\n")
      {%SSE{lines: ["data can have more :'s in it'"]}, ""}

  """
  # parse_block block has comments event does not
  def parse(stream) do
    do_parse(stream, %__MODULE__{})
  end

  defp do_parse(stream, event) do
    case pop_line(stream) do
      nil ->
        nil
      {"", rest} ->
        {event, rest}
      {line, rest} ->
        event = process_line(line, event)
        do_parse(rest, event)
    end
  end

  defp pop_line(stream) do
    case String.split(stream, @new_line, parts: 2) do
      [^stream] ->
        nil
      [line, rest] ->
        {line, rest}
    end
  end

  defp process_line(line, event) do
    case String.split(line, ~r/: ?/, parts: 2) do
      ["", value] ->
        process_field("comment", value, event)
      [field, value] ->
        process_field(field, value, event)
    end
  end

  defp process_field("event", type, event) do
    Map.put(event, :type, type)
  end
  defp process_field("data", line, event = %{lines: lines}) do
    %{event | lines: lines ++ [line]}
  end
  defp process_field("id", id, event) do
    Map.put(event, :id, id)
  end
  defp process_field("retry", timeout, event) do
    {timeout, ""} = Integer.parse(timeout)
    Map.put(event, :retry, timeout)
  end
  defp process_field("comment", comment, event = %{comments: comments}) do
    %{event | comments: comments ++ [comment]}
  end
end
