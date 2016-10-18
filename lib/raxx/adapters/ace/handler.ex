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
          %{body: body, headers: headers, status: status} ->
            raw = [
              "HTTP/1.1 " <> "#{status}" <> "\r\n",
              "\r\n\r\n",
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
        [path_string, query_string] = case String.split(path_string, "?") do
          [p, q] ->
            [p, q]
          [p] ->
            [p, ""]
        end
        path = path_string |> String.split("/") |> Enum.reject(&empty_string?/1)

        decode_http_request(rest, {method, {path, URI.decode_query(query_string)}, :no_headers, :no_body})
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
          query: query
        }}
    end
  end
  def decode_http_request(buffer) do
    decode_http_request(buffer, {:no_method, :no_path, :no_headers, :no_body})
  end

  defp empty_string?("") do
    true
  end
  defp empty_string?(str) when is_binary(str) do
    false
  end
end
