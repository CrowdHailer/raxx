defmodule Raxx.MethodOverride do
  @behaviour Raxx.Server

  def wrap(next, _options) do
    {__MODULE__, next}
  end

  def handle_head(request, next) do
    request
    |> override_method()
    |> Server.handle_head(next)
  end

  def handle_data(data, next), do: Server.handle_data(data, next)
  def handle_tail(tail, next), do: Server.handle_tail(tail, next)
  def handle_info(info, next), do: Server.handle_info(info, next)

  defp override_method(request = %{method: :POST}) do
    {method, query} = Map.pop(Raxx.get_query(request), "_method", "POST")
    method = String.to_existing_atom(String.upcase(method))
    %{request | method: method, query: query}
  end

  defp override_method(request) do
    request
  end
end
