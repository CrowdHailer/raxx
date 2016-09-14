defmodule ElliForwarder do
  def handle_request(request, env) do
    pid = Map.get(env, :target)
    send(pid, request)
    Raxx.Response.no_content()
  end
end
defmodule Raxx.Adapters.Elli.Callback do
  @behaviour :elli_handler

  def handle(request, {router, env})do
    _response = router.handle_request(normalise_request(request), env)
    {:ok, [], "Ok"}
  end

  def handle_event(:request_error, args, _config)do
    IO.inspect(args)
    :ok
  end
  def handle_event(a,b,c)do
    # IO.inspect(a)
    # IO.inspect(b)
    # IO.inspect(c)
    :ok
  end

  def normalise_request(elli_request) do
    # Elli returns the method as an atom. Maybe this is a better thing to do
    method = "#{:elli_request.method(elli_request)}"
    path = :elli_request.path(elli_request)
    query = :elli_request.get_args_decoded(elli_request) |> Enum.into(%{})
    headers = :elli_request.headers(elli_request) |> Enum.into(%{})
    %{
      method: method,
      path: path,
      query: query,
      headers: headers
    }
  end
end
defmodule Raxx.Elli.RequestTest do
  use ExUnit.Case, async: true

  test "request shows correct method" do
    {:ok,pid}=:elli.start_link [
      callback: Raxx.Adapters.Elli.Callback,
      callback_args: {ElliForwarder, %{target: self()}},
      port: 2020]
    port = 2020
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{method: "GET"}
  end

  test "request shows correct path for root" do
    {:ok,pid}=:elli.start_link [
      callback: Raxx.Adapters.Elli.Callback,
      callback_args: {ElliForwarder, %{target: self()}},
      port: 2020]
    port = 2020
    {:ok, _resp} = HTTPoison.get("localhost:#{port}")
    assert_receive %{path: []}
  end

  test "request shows correct path for sub path" do
    {:ok,pid}=:elli.start_link [
      callback: Raxx.Adapters.Elli.Callback,
      callback_args: {ElliForwarder, %{target: self()}},
      port: 2020]
    port = 2020
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/sub/path")
    assert_receive %{path: ["sub", "path"]}
  end

  test "request shows empty query" do
    {:ok,pid}=:elli.start_link [
      callback: Raxx.Adapters.Elli.Callback,
      callback_args: {ElliForwarder, %{target: self()}},
      port: 2020]
    port = 2020
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/#")
    assert_receive %{query: %{}}
  end

  test "request shows correct query" do
    {:ok,pid}=:elli.start_link [
      callback: Raxx.Adapters.Elli.Callback,
      callback_args: {ElliForwarder, %{target: self()}},
      port: 2020]
    port = 2020
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/?foo=bar")
    assert_receive %{query: %{"foo" => "bar"}}
  end

  test "request assumes maps headers" do
    {:ok,pid}=:elli.start_link [
      callback: Raxx.Adapters.Elli.Callback,
      callback_args: {ElliForwarder, %{target: self()}},
      port: 2020]
    port = 2020
    {:ok, _resp} = HTTPoison.get("localhost:#{port}/", [{"content-type", "unknown/stuff"}])
    assert_receive %{headers: %{"Content-Type" => content_type}}
    assert "unknown/stuff" == content_type
  end

end
