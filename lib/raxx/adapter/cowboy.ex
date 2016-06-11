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
    # Server information
    {host, req} = :cowboy_req.host req

    {port, req} = :cowboy_req.port req

    # Request header information
    {method, req} = :cowboy_req.method req

    {path, req} = :cowboy_req.path req
    path = String.split(path, "/") |> Enum.reject(fn (segment) ->  segment == "" end)

    {qs, req}   = :cowboy_req.qs req
    query = URI.decode_query(qs)

    {headers, req}   = :cowboy_req.headers req
    headers = Enum.into(headers, %{})

    # Body
    {:ok, body_qs, _}  = :cowboy_req.body_qs(req, []) # options kw_args [length: bits]
    body = Enum.into(body_qs, %{})

    # {peer, req} = :cowboy_req.peer req

    # Request
    %Raxx.Request{
      host: host,
      port: port,
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body
    }
  end

  # def parse_body(body, %{"content-type" => "application/x-www-form-urlencoded; charset=utf-8"}) do
  #   URI.decode_www_form(body) |> URI.decode_query
  # end
  # def parse_body(body, _) do
  #   body
  # end

end
