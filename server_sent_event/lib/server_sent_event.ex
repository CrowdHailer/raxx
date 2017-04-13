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
  """

  @new_line ~r/\R/

  defstruct [
    type: nil,
    lines: [],
    id: nil,
    retry: nil,
    comments: []
  ]

  def mime_type do
    "text/event-stream"
  end

  def empty?(%{lines: []}), do: true
  def empty?(%{lines: _}), do: false

  def serialize(event) do

  end

  @doc """
  Parse an event from text stream.

  ## Examples
  *In these examples this module has been aliased to `SSE`.

      iex> SSE.parse("data: This is the first message\\n\\n")
      {%SSE{lines: ["This is the first message"]}, ""}

      iex> SSE.parse("data:First whitespace character is optional\\n\\n")
      {%SSE{lines: ["First whitespace character is optional"]}, ""}

      iex> SSE.parse("data: This message\\ndata: has two lines.\\n\\n")
      {%SSE{lines: ["This message", "has two lines."]}, ""}

      iex> SSE.parse("event: custom\\ndata: This message is type custom\\n\\n")
      {%SSE{type: "custom", lines: ["This message is type custom"]}, ""}

      iex> SSE.parse("id: 100\\ndata: This message has an id\\n\\n")
      {%SSE{id: "100", lines: ["This message has an id"]}, ""}

      iex> SSE.parse("retry: 5000\\ndata: This message retries after 5s.\\n\\n")
      {%SSE{retry: 5000, lines: ["This message retries after 5s."]}, ""}

      iex> SSE.parse(": This is a comment\\n\\n")
      {%SSE{comments: ["This is a comment"]}, ""}

      iex> SSE.parse("data: This message is not complete")
      nil

  """
  # parse_block block has comments event does not
  def parse(stream, event \\ %__MODULE__{}) do
    case pop_line(stream) do
      nil ->
        nil
      {"", rest} ->
        {event, rest}
      {line, rest} ->
        event = process_line(line, event)
        parse(rest, event)
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
    case String.split(line, ~r/: ?/) do
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
