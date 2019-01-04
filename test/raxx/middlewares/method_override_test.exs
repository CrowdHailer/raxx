defmodule Raxx.Middlewares.MethodOverrideTest do
  use ExUnit.Case
  import Raxx
  import Raxx.Middlewares.MethodOverride
  doctest Raxx.Middlewares.MethodOverride

  alias Raxx.Server

  defmodule SimpleApp do
    use Raxx.SimpleServer

    @impl Raxx.SimpleServer
    def handle_request(request, _) do
      send(self(), request)

      response(:ok)
      |> set_body("Hello, World!")
    end
  end

  setup do
    stack = Raxx.Stack.new([{Raxx.Middlewares.MethodOverride, nil}], {SimpleApp, nil})
    {:ok, stack: stack}
  end

  test "Query can be used to overwrite POST method", %{stack: stack} do
    request = request(:POST, "/?_method=PUT")

    assert {[response], _} = Server.handle_head(stack, request)
    assert_receive %{method: :PUT}
    assert response.body == "Hello, World!"
  end
end
