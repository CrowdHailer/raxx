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

  def read_request(latest, {:headers, buffer, request = %{headers: headers}}) do
    buffer = buffer <> latest
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:more, :undefined} ->
        {:more, {:headers, buffer, request}}
      {:ok, {:http_header, _, key, _, value}, rest} ->
        read_request("", {:headers, rest, add_header(request, key, value)})
      {:ok, :http_eoh, body} ->
        {:ok, %Raxx.Request{request | body: body}}
    end
  end
  def read_request(latest, {:start_line, buffer, conn}) do
    buffer = buffer <> latest
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:more, :undefined} ->
        {:more, {:start_line, buffer, conn}}
      {:ok, {:http_request, method, {:abs_path, path_string}, _version}, rest} ->
        {path, query} = Raxx.Request.parse_path(path_string)
        request = %Raxx.Request{method: method, path: path, query: query, headers: []}
        read_request("", {:headers, rest, request})
    end
  end

  # TODO case when adding key "Host" or "host"
  def add_header(request = %{headers: headers}, :Host, location) do
    [host, port] = case String.split(location, ":") do
      [host, port] -> [host, :erlang.binary_to_integer(port)]
      [host] -> [host, 80]
    end
    headers = headers ++ [{"host", location}]
    %{request | headers: headers, host: host, port: port}
  end
  def add_header(request = %{headers: headers}, key, value) do
    key = String.downcase("#{key}")
    headers = headers ++ [{key, value}]
    %{request | headers: headers}
  end
end
