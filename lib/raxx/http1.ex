defmodule Raxx.HTTP1 do
  @moduledoc """

  ## Property testing

  Functionality in this module might be a good opportunity for property based testing.
  Elixir Outlaws convinced me to give it a try.

  - Property of serialize then decode the head should end up with the same struct
  - Propery of any number of splits in the binary should not change the output
  """

  @crlf "\r\n"

  @doc """
  ## Examples
      iex> request = Raxx.request(:GET, "http://example.com/path?qs")
      ...> |> Raxx.set_header("accept", "text/plain")
      ...> {head, _body} =  Raxx.HTTP1.serialize_request(request)
      ...> :erlang.iolist_to_binary(head)
      "GET /path?qs HTTP/1.1\\r\\nhost: example.com\\r\\naccept: text/plain\\r\\n\\r\\n"

      iex> request = Raxx.request(:POST, "https://example.com/path")
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {head, _body} =  Raxx.HTTP1.serialize_request(request)
      ...> :erlang.iolist_to_binary(head)
      "POST /path HTTP/1.1\\r\\nhost: example.com\\r\\ntransfer-encoding: chunked\\r\\ncontent-type: text/plain\\r\\n\\r\\n"

      iex> request = Raxx.request(:POST, "https://example.com/path")
      ...> |> Raxx.set_header("content-length", "13")
      ...> |> Raxx.set_body(true)
      ...> {head, _body} =  Raxx.HTTP1.serialize_request(request)
      ...> :erlang.iolist_to_binary(head)
      "POST /path HTTP/1.1\\r\\nhost: example.com\\r\\ncontent-length: 13\\r\\n\\r\\n"
  """
  def serialize_request(request = %Raxx.Request{}) do
    {payload_headers, body} = payload(request)
    headers = [{"host", request.authority}] ++ payload_headers ++ request.headers
    head = [start_line(request), header_lines(headers), @crlf]
    {head, body}
  end

  @doc """
  Serialize a request or response an iolist

  serialize_request(%{}) -> {iolist, :complete}
  # Need to consider if parsing a request with not all body.
  parse_request(iolist) -> {:ok, {request, :complete, iolist}}
  # should this return request or [request, body, end]
  parse_request(iolist) -> {:ok, {request, {:bytes, 50}, iolist}}

  Because of HEAD requests we should keep body separate
  ## Examples

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body("Hello, World!")
      ...> {head, _body} =  Raxx.HTTP1.serialize_response(response)
      ...> :erlang.iolist_to_binary(head)
      "HTTP/1.1 200 OK\\r\\ncontent-length: 13\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      # ...> body
      # "Hello, World!"

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body("Hello, World!")
      ...> {_head, body} =  Raxx.HTTP1.serialize_response(response)
      # ...> :erlang.iolist_to_binary(head)
      # "HTTP/1.1 200 OK\\r\\ncontent-length: 13\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      ...> body
      {:complete, "Hello, World!"}

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-length", "13")
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> {head, _body} =  Raxx.HTTP1.serialize_response(response)
      ...> :erlang.iolist_to_binary(head)
      "HTTP/1.1 200 OK\\r\\ncontent-length: 13\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      # ...> body
      # "Hello, World!"

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-length", "13")
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {_head, body} =  Raxx.HTTP1.serialize_response(response)
      # ...> :erlang.iolist_to_binary(head)
      # "HTTP/1.1 200 OK\\r\\ncontent-length: 13\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      ...> body
      {:bytes, 13}

      > A server MUST NOT send a Content-Length header field in any response
      > with a status code of 1xx (Informational) or 204 (No Content).  A
      > server MUST NOT send a Content-Length header field in any 2xx
      > (Successful) response to a CONNECT request (Section 4.3.6 of
      > [RFC7231]).

      iex> Raxx.response(204)
      ...> |> Raxx.set_header("foo", "bar")
      ...> |> Raxx.HTTP1.serialize_response()
      ...> |> elem(0)
      ...> |> :erlang.iolist_to_binary()
      "HTTP/1.1 204 No Content\\r\\nfoo: bar\\r\\n\\r\\n"
  """
  @spec serialize_response(Raxx.Response.t()) ::
          {iolist, {:complete, iodata} | {:bytes, non_neg_integer() | :chunked}}
  def serialize_response(response = %Raxx.Response{}) do
    {payload_headers, body} = payload(response)
    headers = payload_headers ++ response.headers
    head = [response_line(response), header_lines(headers), @crlf]
    {head, body}
  end

  # @spec parse_request() :: {:}
  def parse do
  end

  @doc """
  TODO needs error case
  """
  def parse_chunk(buffer) do
    case String.split(buffer, "\r\n", parts: 2) do
      [base_16_size, rest] ->
        size =
          base_16_size
          |> :erlang.binary_to_list()
          |> :erlang.list_to_integer(16)

        case rest do
          <<chunk::binary-size(size), "\r\n", rest::binary>> ->
            {chunk, rest}

          _incomplete_chunk ->
            {nil, buffer}
        end

      [rest] ->
        {nil, rest}
    end
  end

  defp start_line(%Raxx.Request{method: method, raw_path: path, query: query}) do
    query_string = if query, do: ["?", query], else: ""
    [Atom.to_string(method), " ", path, query_string, " HTTP/1.1", @crlf]
  end

  defp response_line(%Raxx.Response{status: status}) do
    [
      "HTTP/1.1 ",
      Integer.to_string(status),
      " ",
      Raxx.reason_phrase(status),
      @crlf
    ]
  end

  defp header_lines(headers) do
    Enum.map(headers, fn {key, value} -> [key, ": ", value, @crlf] end)
  end

  defp payload(%{headers: headers, body: true}) do
    case content_length(headers) do
      nil ->
        {[{"transfer-encoding", "chunked"}], :chunked}

      content_length ->
        {[], {:bytes, content_length}}
    end
  end

  defp payload(message = %{body: false}) do
    payload(%{message | body: ""})
  end

  defp payload(%{headers: headers, body: iodata}) do
    payload_headers =
      case content_length(headers) do
        nil ->
          # NOTE `:erlang.iolist_size/1` acceps binaries, i.e. should be `:erlang.iodata_size/1`
          case :erlang.iolist_size(iodata) do
            0 ->
              []

            content_length ->
              [{"content-length", Integer.to_string(content_length)}]
          end

        _value ->
          # If a content-length is already set it is the callers responsibility to set the correct value
          []
      end

    {payload_headers, {:complete, iodata}}
  end

  defp content_length(headers) do
    case :proplists.get_all_values("content-length", headers) do
      [] ->
        nil

      [binary] ->
        {content_length, ""} = Integer.parse(binary)
        content_length
    end
  end
end
