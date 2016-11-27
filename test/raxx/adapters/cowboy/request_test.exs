defmodule Raxx.Adapters.Cowboy.RequestTest do
  use Raxx.Adapters.RequestCase

  case Application.ensure_all_started(:cowboy) do
    {:ok, _} ->
      :ok
    {:error, {:cowboy, _}} ->
      raise "could not start the cowboy application. Please ensure it is listed " <>
            "as a dependency both in deps and application in your mix.exs"
  end

  setup %{case: case, test: test} do
    name = {case, test}
    routes = [
      {:_, Raxx.Adapters.Cowboy.Handler, {Raxx.TestSupport.Forwarder, %{target: self()}}}
    ]
    dispatch = :cowboy_router.compile([{:_, routes}])
    env = [dispatch: dispatch]
    {:ok, _pid} = :cowboy.start_http(name, 2, [port: 0], [env: env])
    {:ok, %{port: :ranch.get_port(name)}}
  end

  test "post multipart form with file", %{port: port} do
    body = {:multipart, [{"foo", "bar"}, {:file, "/etc/hosts"}]}
    {:ok, _resp} = HTTPoison.post("localhost:#{port}", body)
    assert_receive r = %{headers: headers, body: body}
    IO.inspect r
    # IO.inspect(headers)
    # IO.inspect(rest)
    # IO.inspect(body)
    # assert %{"foo" => "bar", "file" => file} = body
    # assert file.contents
  end

end
