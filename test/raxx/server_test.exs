defmodule Raxx.ServerTest do
  use ExUnit.Case
  doctest Raxx.Server

  defmodule EchoServer do
    use Raxx.Server, type: :simple

    def handle_request(%{body: body}, _) do
      response(:ok)
      |> set_body(inspect(body))
    end
  end

  test "body is concatenated to single string" do
    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_body(true)

    state = %{}

    assert {[], state} = EchoServer.handle_head(request, state)
    assert {[], state} = EchoServer.handle_data("a", state)
    assert {[], state} = EchoServer.handle_data("b", state)
    assert {[], state} = EchoServer.handle_data("c", state)
    assert %{body: body} = EchoServer.handle_tail([], state)
    assert "\"abc\"" == body
  end

  test "default server will not butter more than 8MB into one request" do
    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_body(true)

    state = %{}

    assert {[], state} = EchoServer.handle_head(request, state)
    four_Mb = String.duplicate("1234", round(:math.pow(2, 20)))
    assert {[], state} = EchoServer.handle_data(four_Mb, state)
    assert {[], state} = EchoServer.handle_data(four_Mb, state)
    assert response = %{status: 413} = EchoServer.handle_data("straw", state)
  end

  defmodule BigServer do
    use Raxx.Server, type: :simple, maximum_body_length: 12 * 1024 * 1024

    def handle_request(_, _) do
      response(:ok)
    end
  end

  test "Server max body size can be configured" do
    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_body(true)

    state = %{}

    assert {[], state} = BigServer.handle_head(request, state)
    four_Mb = String.duplicate("1234", round(:math.pow(2, 20)))
    assert {[], state} = BigServer.handle_data(four_Mb, state)
    assert {[], state} = BigServer.handle_data(four_Mb, state)
    assert {[], state} = BigServer.handle_data(four_Mb, state)
    assert response = %{status: 413} = BigServer.handle_data("straw", state)
  end
end
