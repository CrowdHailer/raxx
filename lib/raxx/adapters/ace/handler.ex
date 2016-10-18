defmodule Raxx.Adapters.Ace.Handler do
  def init(conn, app) do
    {:nosend, {app, "", conn}}
  end

  def handle_packet(line, {app, buffer, conn}) do
    buffer = buffer <> line
    decode_request(buffer)
    case decode_request(buffer) do
      {:ok, request} ->
        {mod, state} = app
        mod.handle_request(request, state)
        case mod.handle_request(request, state) do
          %{body: body, headers: headers, status: status_code} ->
            header_line = Enum.map(headers, fn({x, y}) -> "#{x}: #{y}" end)
            raw = [
              Raxx.Response.status_line(status_code),
              Enum.join(header_line, "\r\n"),
              "\r\n",
              "\r\n",
              body
            ]
            {:send, raw, {app, "", conn}}
        end

    end
  end

  def terminate(_reason, {_app, buffer, _conn}) do
    IO.inspect(buffer)
  end

  def decode_headers(buffer) do
    decode_headers(buffer, [])
  end

  def decode_headers(buffer, headers) do
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:ok, {:http_header, _, key, _, value}, rest} ->
        headers = headers ++ [{key, value}]
        decode_headers(rest, headers)
      {:ok, :http_eoh, rest} ->
        {:ok, headers, rest}
    end
  end

  def decode_request(buffer) do
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:ok, {:http_request, method, {:abs_path, path_string}, _version}, rest} ->
        {path, query} = Raxx.Request.parse_path(path_string)

        {:ok, headers, body} = decode_headers(rest)

        {:Host, authority} = headers |> List.keyfind(:Host, 0)
        [host, port] = String.split(authority, ":")
        
        {:ok, %Raxx.Request{
          host: host,
          port: :erlang.binary_to_integer(port),
          method: method,
          path: path,
          query: query,
          headers: Enum.map(headers, fn ({k, v}) ->
            {String.downcase("#{k}"), String.downcase("#{v}")}
          end),
          body: body
        }}
    end
  end
end
