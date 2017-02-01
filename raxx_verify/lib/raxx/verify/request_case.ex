defmodule Raxx.Verify.RequestCase do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      test "request shows correct scheme", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{scheme: "http"}
      end

      test "request shows localhost", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{host: "localhost"}
      end

      test "request shows correct host", %{port: port} do
        {:ok, _resp} = HTTPoison.get("0.0.0.0:#{port}")
        assert_receive %{host: "0.0.0.0"}
      end

      test "request shows correct port", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{port: ^port}
      end

      test "request shows correct method", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}")
        assert_receive %{method: :GET}
      end

      test "request shows correct method when posting", %{port: port} do
        {:ok, _resp} = HTTPoison.post("localhost:#{port}", "")
        assert_receive %{method: :POST}
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

      test "request shows correct header", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
        assert_receive %{headers: headers}
        assert {"content-type", "unknown/stuff"} == List.keyfind(headers, "content-type", 0)
      end

      test "request downcases headers", %{port: port} do
        {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"Content-Type", "unknown/stuff"}])
        assert_receive %{headers: headers}
        assert {"content-type", "unknown/stuff"} == List.keyfind(headers, "content-type", 0)
      end

      test "request has correct body", %{port: port} do
        {:ok, _resp} = HTTPoison.post("localhost:#{port}", "blah blah")
        assert_receive %{body: body}
        assert "blah blah" == body
      end
    end
  end
end
