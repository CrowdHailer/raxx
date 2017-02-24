defmodule Raxx.Elli.Handler do
  @moduledoc false
  @behaviour :elli_handler

  # router rename raxx_handler
  def handle(elli_request, {router, env})do
    request = normalise_request(elli_request)
    response = router.handle_request(request, env)
    case response do
      %{status: status, headers: headers, body: body} ->
        {status, marshal_headers(headers), body}
    end
  end

  def handle_event(:request_error, args, _config)do
    IO.inspect(args)
    :ok
  end
  def handle_event(_a,_b,_c)do
    # IO.inspect(a)
    # IO.inspect(b)
    # IO.inspect(c)
    :ok
  end

  def normalise_request(elli_request) do
    method = :elli_request.method(elli_request)
    path = :elli_request.path(elli_request)
    query = :elli_request.get_args_decoded(elli_request) |> Enum.into(%{})
    headers = :elli_request.headers(elli_request) |> Enum.map(fn ({k, v}) ->
      {String.downcase(k), String.downcase(v)}
    end)
    {"Host", authority} = :elli_request.headers(elli_request) |> List.keyfind("Host", 0)
    # [host, port] = String.split(authority, ":") - authority might not contain a port, and may crash here
    [host, port] = case String.split(authority, ":") do
       [host, port] -> [host, port]
       [host] -> [host, 80] # we need to set the correct port some how...
     end
     
    %{
      scheme: "http", # we need to set the correct scheme too for :ssl
      host: host,
      port: :erlang.binary_to_integer(port),
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: :elli_request.body(elli_request)
    }
  end

  # TODO remove this in the future.
  def marshal_headers(%{}) do
    []
  end
  def marshal_headers(headers) do
    headers
  end
end
