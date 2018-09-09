defmodule Raxx.ServerTest do
  use ExUnit.Case
  doctest Raxx.Server
  import ExUnit.CaptureLog

  defmodule DefaultServer do
    use Raxx.Server
  end

  test "default response is returned for the root page" do
    request = Raxx.request(:GET, "/")
    response = DefaultServer.handle_request(request, :state)

    assert String.contains?(response.body, "DefaultServer")
    assert String.contains?(response.body, "@impl Raxx.Server")
    assert 404 = response.status
  end

  test "default response is returned for a streamed request" do
    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_body(true)

    {[], state} = DefaultServer.handle_head(request, :state)
    {[], state} = DefaultServer.handle_data("Hello, World!", state)
    response = DefaultServer.handle_tail([], state)

    assert String.contains?(response.body, "DefaultServer")
    assert String.contains?(response.body, "@impl Raxx.Server")
    assert 404 = response.status
  end

  test "handle_info logs error" do
    logs =
      capture_log(fn ->
        DefaultServer.handle_info(:foo, :state)
      end)

    assert String.contains?(logs, "unexpected message")
    assert String.contains?(logs, ":foo")
  end

  test "default server will not butter more than 8MB into one request" do
    request =
      Raxx.request(:POST, "/")
      |> Raxx.set_body(true)

    state = %{}

    assert {[], state} = DefaultServer.handle_head(request, state)
    four_Mb = String.duplicate("1234", round(:math.pow(2, 20)))
    assert {[], state} = DefaultServer.handle_data(four_Mb, state)
    assert {[], state} = DefaultServer.handle_data(four_Mb, state)
    assert response = %{status: 413} = DefaultServer.handle_data("straw", state)
  end

  defmodule BigServer do
    use Raxx.Server, maximum_body_length: 12 * 1024 * 1024
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
