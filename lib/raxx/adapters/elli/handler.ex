defmodule Raxx.Adapters.Elli.Handler do
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
