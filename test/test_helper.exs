defmodule Raxx.TestSupport.Forwarder do
  def handle_request(request, env) do
    pid = Map.get(env, :target)
    send(pid, request)
    Raxx.Response.no_content()
  end
end
defmodule Raxx.TestSupport.Responder do
  def handle_request(request, env) do
    pid = Map.get(env, :target)
    send(pid, {:request, self()})
    receive do
      {:response, response} ->
        response
    end
  end
end
case Application.ensure_all_started(:cowboy) do
  {:ok, _} ->
    :ok
  {:error, {:cowboy, _}} ->
    raise "could not start the cowboy application. Please ensure it is listed " <>
          "as a dependency both in deps and application in your mix.exs"
end
ExUnit.start()
