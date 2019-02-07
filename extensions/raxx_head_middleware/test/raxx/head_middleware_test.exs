defmodule Raxx.HeadMiddlewareTest do
  use ExUnit.Case
  import Raxx

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
    stack = Raxx.Stack.new([{Raxx.HeadMiddleware, nil}], {SimpleApp, nil})
    {:ok, stack: stack}
  end

  test "The response to a GET request is unchanged", %{stack: stack} do
    request = request(:GET, "/")

    assert {[response], _} = Server.handle_head(stack, request)
    assert_receive %{method: :GET}
    assert response.body == "Hello, World!"
  end

  test "The response to a HEAD request is returned without body", %{stack: stack} do
    request = request(:HEAD, "/")

    assert {[response], _} = Server.handle_head(stack, request)
    assert_receive %{method: :GET}
    assert get_content_length(response) == 13
    assert response.body == false
  end

  test "A POST request is unchanged", %{stack: stack} do
    request =
      request(:POST, "/")
      |> set_body(true)

    assert {[], stack} = Server.handle_head(stack, request)
    assert {[], stack} = Server.handle_data(stack, "some data")
    assert {[response], _} = Server.handle_tail(stack, [])
    assert_receive %{method: :POST}
    assert response.body == "Hello, World!"
  end
end
