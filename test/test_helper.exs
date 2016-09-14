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

ExUnit.start()
