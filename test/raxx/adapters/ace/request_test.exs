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

defmodule Raxx.Ace.RequestTest do
  use Raxx.Adapters.RequestCase

  setup %{case: case, test: test} do
    raxx_app = {Raxx.TestSupport.Forwarder, %{target: self()}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

  @tag :skip
  test "request shows correct host", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{host: "localhost"}
  end

  @tag :skip
  # currently only the peer port is available.
  test "request shows correct port", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{port: ^port}
  end

  test "request shows correct path for root", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{path: []}
  end

  test "request shows correct path for sub path", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/sub/path")
    assert_receive %{path: ["sub", "path"]}
  end

  test "request shows empty query", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/#")
    assert_receive %{query: %{}}
  end

  test "request shows correct query", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?foo=bar")
    assert_receive %{query: %{"foo" => "bar"}}
  end

  @tag :skip
  test "request assumes maps headers", %{port: port} do
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
    assert_receive %{headers: %{"content-type" => content_type}}
    assert "unknown/stuff" == content_type
  end

end
