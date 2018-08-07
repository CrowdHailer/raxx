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
  # NOTE set_body should add content-length otherwise we don't know if to delete it to match on other end, when serializing

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
  ## Examples

      iex> "GET /path?qs HTTP/1.1\\r\\nhost: example.com\\r\\naccept: text/plain\\r\\n\\r\\n"
      ...> |> Raxx.HTTP1.parse_request()
      {:ok,
       %Raxx.Request{
         authority: "example.com",
         body: false,
         headers: [{"accept", "text/plain"}],
         method: :GET,
         mount: [],
         path: ["path"],
         query: "qs",
         raw_path: "/path",
         scheme: :http
       }, {:complete, ""}, ""}

      iex> "POST /path HTTP/1.1\\r\\nhost: example.com\\r\\ntransfer-encoding: chunked\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      ...> |> Raxx.HTTP1.parse_request()
      {:ok,
       %Raxx.Request{
         authority: "example.com",
         body: true,
         headers: [{"content-type", "text/plain"}],
         method: :POST,
         mount: [],
         path: ["path"],
         query: nil,
         raw_path: "/path",
         scheme: :http
       }, :chunked, ""}

      iex> "POST /path HTTP/1.1\\r\\nhost: example.com\\r\\ncontent-length: 13\\r\\n\\r\\n"
      ...> |> Raxx.HTTP1.parse_request()
      {:ok,
       %Raxx.Request{
         authority: "example.com",
         body: true,
         headers: [{"content-length", "13"}],
         method: :POST,
         mount: [],
         path: ["path"],
         query: nil,
         raw_path: "/path",
         scheme: :http
       }, {:bytes, 13}, ""}

      iex> "GET /path?qs HT"
      ...> |> Raxx.HTTP1.parse_request()
      {:more, "GET /path?qs HT"}

      iex> "GET /path?qs HTTP/1.1\\r\\nhost: exa"
      ...> |> Raxx.HTTP1.parse_request()
      {:more, "GET /path?qs HTTP/1.1\\r\\nhost: exa"}

  """
  def parse_request(buffer, scheme \\ :http) do
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:ok, {:http_request, method, {:abs_path, path_and_query}, _version}, rest} ->
        case parse_headers(rest) do
          {:ok, headers, rest2} ->
            case Enum.split_with(headers, fn {key, _value} -> key == "host" end) do
              {[{"host", host}], headers} ->
                {headers, body, state} = decode_payload(headers)

                request =
                  Raxx.request(method, path_and_query)
                  |> Map.put(:scheme, scheme)
                  |> Map.put(:authority, host)
                  |> Map.put(:headers, headers)
                  |> Map.put(:body, body)

                {:ok, request, state, rest2}
            end

          {:more, :undefined} ->
            {:more, buffer}
        end

      {:more, :undefined} ->
        {:more, buffer}
    end
  end

  defp parse_headers(buffer, headers \\ []) do
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:ok, :http_eoh, rest} ->
        {:ok, Enum.reverse(headers), rest}

      {:ok, {:http_header, _, key, _, value}, rest} ->
        parse_headers(rest, [{String.downcase("#{key}"), value} | headers])

      {:more, :undefined} ->
        {:more, :undefined}
    end
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

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {head, _body} =  Raxx.HTTP1.serialize_response(response)
      ...> :erlang.iolist_to_binary(head)
      "HTTP/1.1 200 OK\\r\\ntransfer-encoding: chunked\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      # ...> body
      # :chunked

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {_head, body} =  Raxx.HTTP1.serialize_response(response)
      # ...> :erlang.iolist_to_binary(head)
      # "HTTP/1.1 200 OK\\r\\ntransfer-encoding: chunked\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      ...> body
      :chunked

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

  @doc """
  ## Examples

      iex> "HTTP/1.1 204 No Content\\r\\nfoo: bar\\r\\n\\r\\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, %Raxx.Response{
        status: 204,
        headers: [{"foo", "bar"}],
        body: false
      }, {:complete, ""}, ""}

      iex> "HTTP/1.1 200 OK\\r\\ncontent-length: 13\\r\\ncontent-type: text/plain\\r\\n\\r\\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, %Raxx.Response{
        status: 200,
        headers: [{"content-length", "13"}, {"content-type", "text/plain"}],
        body: true
      }, {:bytes, 13}, ""}
  """
  def parse_response(buffer) do
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:ok, {:http_response, {1, 1}, status, _reason_phrase}, rest} ->
        case parse_headers(rest) do
          {:ok, headers, rest2} ->
            {headers, body, state} = decode_payload(headers)
            {:ok, %Raxx.Response{status: status, headers: headers, body: body}, state, rest2}
        end
    end
  end

  defp decode_payload(headers) do
    case Enum.split_with(headers, fn {key, _value} -> key == "transfer-encoding" end) do
      {[{"transfer-encoding", "chunked"}], headers} ->
        {headers, true, :chunked}

      {[], headers} ->
        case content_length(headers) do
          nuffink when nuffink in [nil, 0] ->
            {headers, false, {:complete, ""}}

          bytes ->
            {headers, true, {:bytes, bytes}}
        end
    end
  end

  @doc """
  Serialize io_data as a single chunk to be streamed.

  ## Example

      iex> Raxx.HTTP1.serialize_chunk("hello")
      ...> |> to_string()
      "5\\r\\nhello\\r\\n"

      iex> Raxx.HTTP1.serialize_chunk("")
      ...> |> to_string()
      "0\\r\\n\\r\\n"
  """
  def serialize_chunk(data) do
    size = :erlang.iolist_size(data)
    [:erlang.integer_to_list(size, 16), "\r\n", data, "\r\n"]
  end

  @doc """
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
            {:ok, {chunk, rest}}

          _incomplete_chunk ->
            {:ok, {nil, buffer}}
        end

      [rest] ->
        {:ok, {nil, rest}}
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
