defmodule Raxx.TestSupport.Forwarder do
  def handle_request(request, env) do
    pid = Map.get(env, :target)
    send(pid, request)
    Raxx.Response.no_content()
  end
end


{:ok, _} = Application.ensure_all_started(:httpoison)
ExUnit.start()
