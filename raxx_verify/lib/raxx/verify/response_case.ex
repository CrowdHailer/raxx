defmodule Raxx.Verify.ResponseCase do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      def handle_request(request = %{path: path = [function | _rest]}, _env) do
        apply(__MODULE__, String.to_atom(function), [request])
      end

      def hello_world(request) do
        body = "Hello, World!"
        Raxx.Response.ok(body, [
          {"content-length", "#{:erlang.iolist_size(body)}"},
          {"custom-header", "my-value"}
        ])
      end

      test "Hello response has correct status", %{port: port} do
        {:ok, response} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert %{status_code: 200} = response
      end

      test "Hello response has content length header", %{port: port} do
        {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert {"content-length", "13"} = List.keyfind(headers, "content-length", 0)
      end

      test "Hello response has custom header", %{port: port} do
        {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert {"custom-header", "my-value"} = List.keyfind(headers, "custom-header", 0)
      end

      test "Hello response greeting body", %{port: port} do
        {:ok, %{body: body}} = HTTPoison.get("localhost:#{port}/hello_world", [])
        assert "Hello, World!" = body
      end
    end
  end
end
