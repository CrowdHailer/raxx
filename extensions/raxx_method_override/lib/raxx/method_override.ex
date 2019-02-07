defmodule Raxx.MethodOverride do
  @moduledoc """
  Allows browser to emulate using HTTP verbs other than `POST`.

  Only the `POST` method will be overridden,
  It can be overridden to any of the listed HTTP verbs.
  - `PUT`
  - `PATCH`
  - `DELETE`

  The emulated method is is denoted by the `_method` parameter of the url query.

  ## Examples

      # override POST to PUT from query value
      iex> request(:POST, "/?_method=PUT")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :PUT

      # override POST to PATCH from query value
      iex> request(:POST, "/?_method=PATCH")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :PATCH

      # override POST to DELETE from query value
      iex> request(:POST, "/?_method=DELETE")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :DELETE

      # overridding method removes the _method field from the query
      iex> request(:POST, "/?_method=PUT")
      ...> |> override_method()
      ...> |> Map.get(:query)
      %{}

      # override works with lowercase query value
      iex> request(:POST, "/?_method=delete")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :DELETE

      # # at the moment breaks deleberatly due to unknown method
      # # does not allow unknown methods
      # iex> request(:POST, "/?_method=PARTY")
      # ...> |> override_method()
      # ...> |> Map.get(:method)
      # :POST

      # leaves non-POST requests unmodified, e.g. GET
      iex> request(:GET, "/?_method=DELETE")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :GET

      # leaves non-POST requests unmodified, e.g. PUT
      # Not entirely sure of the logic here.
      iex> request(:PUT, "/?_method=DELETE")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :PUT

      # queries with out a _method field are a no-op
      iex> request(:POST, "/?other=PUT")
      ...> |> override_method()
      ...> |> Map.get(:method)
      :POST
  """

  use Raxx.Middleware

  @doc """
  Modify a requests method based on query parameters
  """
  def override_method(request = %{method: :POST}) do
    query = Raxx.get_query(request)
    {method, query} = Map.pop(query, "_method")

    case method && String.upcase(method) do
      nil ->
        request

      method when method in ["PUT", "PATCH", "DELETE"] ->
        method = String.to_existing_atom(method)
        %{request | method: method, query: query}
    end
  end

  def override_method(request) do
    request
  end

  @impl Raxx.Middleware
  def process_head(request, state, next) do
    request = override_method(request)
    {parts, next} = Raxx.Server.handle_head(next, request)
    {parts, state, next}
  end
end
