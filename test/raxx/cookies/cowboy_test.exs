defmodule Raxx.Cookies.TestHandler do
  import Raxx.Response
  def handle_request(_request, _cookies) do
    ok("done")
    |> set_cookie("foo", "foo_value")
  end
end

defmodule Raxx.Cookies.CowboyTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, agent} = Agent.start_link(fn -> 1 end)
    case Application.ensure_all_started(:cowboy) do
      {:ok, _} ->
        {:ok, %{agent: agent}}
      {:error, {:cowboy, _}} ->
        raise "could not start the cowboy application. Please ensure it is listed " <>
              "as a dependency both in deps and application in your mix.exs"
    end
  end

  setup %{agent: agent} do
    id = Agent.get_and_update(agent, fn (i) -> {i, i + 1}end)
    {:ok, %{port: 10_200 + id}}
  end

  def raxx_up(port, app \\ {Forwarder, self}) do
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, app}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    :cowboy.start_http(
      :"test_on_#{port}",
      2,
      [port: port],
      [env: env]
    )
  end

  test "add custom headers to request", %{port: port} do
    {:ok, _pid} = raxx_up(port, {Raxx.Cookies.TestHandler, %{}})
    {:ok, %{headers: headers}} = HTTPoison.get("localhost:#{port}")
    |> IO.inspect
    header = Enum.find(headers, fn
      ({"set-cookie", _}) -> true
      _ -> false
    end)
    assert {_, "key=value"} = header
  end
end
