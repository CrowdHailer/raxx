defmodule Raxx.Adapters.Cowboy.Handler do
  def init({:tcp, :http}, req, opts = {router, raxx_opts}) do
    headers = [{"content-type", "text/plain"}]
    raxx_request = normalise_request(req)
    %{status: status, headers: _headers, body: body} = router.call(raxx_request, raxx_opts)
    {:ok, resp} = :cowboy_req.reply(200, headers, body, req)
    {:ok, resp, opts}
  end

  def handle(req, state) do
    {:ok, req, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  defp normalise_request(req) do
    {host, req} = :cowboy_req.host req
    {port, req} = :cowboy_req.port req
    {path, req} = :cowboy_req.path req
    path = String.split(path, "/") |> Enum.reject(fn (segment) ->  segment == "" end)
    {method, req} = :cowboy_req.method req
    {qs, req}   = :cowboy_req.qs req
    {peer, req} = :cowboy_req.peer req
    query = URI.decode_query(qs)
    %Raxx.Request{
      host: host,
      port: port,
      method: method,
      path: path,
      query: query
    }
  end

end
