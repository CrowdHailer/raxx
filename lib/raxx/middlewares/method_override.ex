defmodule Raxx.MethodOverride do
  @behaviour Raxx.Server

  def wrap(next, _options \\ []) do
    {__MODULE__, next}
  end

  def handle_head(request, next) do
    request = override_method(request)
    Raxx.Server.handle_head(next, request)
  end

  def handle_data(data, next), do: Raxx.Server.handle_data(next, data)
  def handle_tail(tail, next), do: Raxx.Server.handle_tail(next, tail)
  def handle_info(info, next), do: Raxx.Server.handle_info(next, info)

  defp override_method(request = %{method: :POST}) do
    # TODO when method in accepted methods
    {method, query} = Map.pop(Raxx.get_query(request), "_method", "POST")
    method = String.to_existing_atom(String.upcase(method))
    %{request | method: method, query: query}
  end

  defp override_method(request) do
    request
  end

  def handle_request(_, _) do
    raise "Should not be here!"
  end
end
