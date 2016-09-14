defmodule Raxx.Adapters.Elli.Handler do
  @behaviour :elli_handler

  # router rename raxx_handler
  def handle(elli_request, {router, env})do
    request = normalise_request(elli_request)
    response = router.handle_request(request, env)
    case response do
      %{status: status, headers: headers, body: body} ->
        {status, marshal_headers(headers), body}
      {Raxx.Streaming, mod, env, opts} ->
        {:chunk, Map.get(opts, :headers, []), Map.get(opts, :initial, "")}
    end
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

  def marshal_headers(headers) do
    Enum.flat_map(headers, fn ({header, values}) ->
      Enum.map(values, fn (value) -> {header, value} end)
    end)
  end
end
