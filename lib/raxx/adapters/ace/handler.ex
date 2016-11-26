defmodule Raxx.Adapters.Ace.Handler do
  def init(conn, app) do
    status = {:start_line, "", conn}
    {:nosend, {app, status}}
  end

  def handle_packet(packet, {app, status}) do
    case read_request(packet, status) do
      {:more, status} ->
        {:nosend, {app, status}}
      {:ok, request} ->
        {mod, state} = app
        case mod.handle_request(request, state) do
          %{body: body, headers: headers, status: status_code} ->
            header_lines = Enum.map(headers, fn({x, y}) -> "#{x}: #{y}" end)
            raw = [
              Raxx.Response.status_line(status_code),
              Enum.join(header_lines, "\r\n"),
              "\r\n",
              "\r\n",
              body
            ]
            {:send, raw, {app, "", %{}}}
          upgrade = %Raxx.Chunked{} ->
            headers = upgrade.headers

            headers = if !List.keymember?(headers, "content-type", 0) do
              headers ++ [{"content-type", "text/plain"}]
            end || headers
            headers = headers ++ [{"transfer-encoding", "chunked"}]
            response = [
              Raxx.Response.status_line(200),
              Raxx.Response.header_lines(headers),
              "\r\n"
            ]
            {:send, response, {upgrade, status}}
        end
    end
  end

  def handle_info(message, {%Raxx.Chunked{app: {mod, state}}, buffer, conn}) do
    case mod.handle_info(message, state) do
      {:chunk, data, state} ->
        {:send, Raxx.Chunked.to_packet(data), {%Raxx.Chunked{app: {mod, state}}, buffer, conn}}
      {:close, state} ->
        {:send, Raxx.Chunked.end_chunk, {%Raxx.Chunked{app: {mod, state}}, buffer, conn}}
    end
  end
  def terminate(_reason, {_app, buffer, _conn}) do
    IO.inspect(buffer)
    :ok
  end

  def decode_headers(buffer) do
    decode_headers(buffer, [])
  end

  def decode_headers(buffer, headers) do
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:more, :undefined} ->
        {:more, buffer}
      {:ok, {:http_header, _, key, _, value}, rest} ->
        headers = headers ++ [{key, value}]
        decode_headers(rest, headers)
      {:ok, :http_eoh, rest} ->
        {:ok, headers, rest}
    end
  end


  def read_request(latest, {:headers, buffer, request = %{headers: headers}}) do
    buffer = buffer <> latest
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:more, :undefined} ->
        {:more, {:headers, buffer, request}}
      {:ok, {:http_header, _, key, _, value}, rest} ->
        headers = headers ++ [{key, value}]
        read_request("", {:headers, rest, %{request | headers: headers}})
      {:ok, :http_eoh, body} ->
        {:Host, location} = headers |> List.keyfind(:Host, 0)
        [host, port] = case String.split(location, ":") do
          [host, port] -> [host, port]
          [host] -> [host, "80"]
        end

        {:ok, %Raxx.Request{
          host: host,
          port: :erlang.binary_to_integer(port),
          method: request.method,
          path: request.path,
          query: request.query,
          headers: Enum.map(headers, fn ({k, v}) ->
            {String.downcase("#{k}"), String.downcase("#{v}")}
          end),
          body: body
          }}
    end
  end
  def read_request(latest, {:start_line, buffer, conn}) do
    buffer = buffer <> latest
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:more, :undefined} ->
        {:more, {:start_line, buffer, conn}}
      {:ok, {:http_request, method, {:abs_path, path_string}, _version}, rest} ->
        {path, query} = Raxx.Request.parse_path(path_string)
        request = %{method: method, path: path, query: query, headers: []}
        read_request("", {:headers, rest, request})
    end
  end
  def read_request(buffer) do
    IO.inspect(buffer)
    case :erlang.decode_packet(:http_bin, buffer, []) do
      # second element length, only defined for body
      {:more, :undefined} ->
        {:more, buffer}
      {:ok, {:http_request, method, {:abs_path, path_string}, _version}, rest} ->
        {path, query} = Raxx.Request.parse_path(path_string)

        case decode_headers(rest) do
          {:ok, headers, body} ->
            {:Host, location} = headers |> List.keyfind(:Host, 0)
            [host, port] = case String.split(location, ":") do
              [host, port] -> [host, port]
              [host] -> [host, "80"]
            end

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
          {:more, buffer} ->
            {:more, buffer}
        end


    end
  end
end
