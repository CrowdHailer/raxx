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

defmodule Raxx.TestSupport.Streaming do
  def handle_request(request, env) do
    [initial | chunks] = env.chunks
    Process.send_after(self(), chunks, 500)
    Raxx.Streaming.upgrade(__MODULE__, env, %{initial: initial})
  end

  # handle cast?
  def handle_info([], env) do
    :nosend
  end
  def handle_info([message | chunks], env) do
    Process.send_after(self(), chunks, 500)
    {:send, message}
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
