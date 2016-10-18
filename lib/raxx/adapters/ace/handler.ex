defmodule Raxx.Adapters.Ace.Handler do
  def init(conn, app) do
    {:nosend, {app, "", conn}}
  end

  def handle_packet(line, {app, buffer, conn}) do
    buffer = buffer <> line
    decode_http_request(buffer)
    case decode_http_request(buffer) do
      {:ok, request} ->
        {mod, state} = app
        {:ok, {ip, port}} = conn
        request = %{request | port: port}
        mod.handle_request(request, state)
        case mod.handle_request(request, state) do
          %{body: body, headers: headers, status: status_code} ->
            hl = Enum.map(headers, fn({x, y}) -> "#{x}: #{y}" end)
            raw = [
              Raxx.Response.status_line(status_code),
              Enum.join(hl, "\r\n"),
              "\r\n",
              "\r\n",
              body
            ]
            {:send, raw, {app, "", conn}}
        end

    end
  end

  def terminate(reason, {app, buffer, conn}) do
    IO.inspect(buffer)
  end

  def decode_http_request(buffer, {:no_method, _, _, _}) do
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:ok, {:http_request, method, {:abs_path, path_string}, version}, rest} ->
        decode_http_request(rest, {method, Raxx.Request.parse_path(path_string), :no_headers, :no_body})
    end
  end
  def decode_http_request(buffer, {method, path, :no_headers, :no_body}) do
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:ok, {:http_header, _, key, _, value}, rest} ->
        decode_http_request(rest, {method, path, [{key, value}], :no_body})
    end
  end
  def decode_http_request(buffer, {method, {path, query}, headers, :no_body}) do
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:ok, {:http_header, _, key, _, value}, rest} ->
        decode_http_request(rest, {method, {path, query}, headers ++ [{key, value}], :no_body})
      {:ok, :http_eoh, body} ->
        {:ok, %Raxx.Request{
          # host: TODO
          # port: TODO
          method: method,
          path: path,
          query: query,
          headers: Enum.map(headers, fn ({k, v}) ->
            {String.downcase("#{k}"), String.downcase("#{v}")}
          end)
        }}
    end
  end
  def decode_http_request(buffer) do
    decode_http_request(buffer, {:no_method, :no_path, :no_headers, :no_body})
  end
end
