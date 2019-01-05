defmodule CORS do
  @doc """
  ## Examples
      iex> CORS.check(:GET, [], test_config())
      {:ok, :no_cors}

      iex> CORS.check(:OPTIONS, [], test_config())
      {:ok, :no_cors}

      # Need an any config
      # Test config accepts PUT but not delete

  ### Simple CORS requests

      iex> headers = [{"origin", "other.example.com"}]
      ...> CORS.check(:GET, headers, test_config())
      {:ok, {:simple, [{"access-control-allow-origin", "other.example.com"}]}}

      iex> headers = [{"origin", "other.example.com"}]
      ...> CORS.check(:DELETE, headers, test_config())
      {:error, {:simple, :invalid_method}}

  ### Preflight CORS requests

      {:ok, {:preflight, [{"access-control-allow-origin", "other.example.com"}, {"access-control-allow-methods", "PUT"}]}}
      iex> headers = [
      ...>   {"origin", "other.example.com"},
      ...>   {"access-control-request-method", "PUT"},
      ...> ]
      ...> CORS.check(:OPTIONS, headers, test_config())
      {:ok, {:preflight, [{"access-control-allow-origin", "other.example.com"}, {"access-control-allow-methods", "PUT"}]}}

      iex> headers = [
      ...>   {"origin", "bad.example.com"},
      ...>   {"access-control-request-method", "PUT"},
      ...> ]
      ...> CORS.check(:OPTIONS, headers, test_config())
      {:error, {:preflight, :invalid_origin}}
  """
  def check(method, headers, config) do
    case :proplists.get_all_values("origin", headers) do
      [] ->
        {:ok, :no_cors}

      [request_origin] ->
        case {method, :proplists.get_all_values("access-control-request-method", headers)} do
          {:OPTIONS, [request_method]} ->
            check_preflight(request_origin, request_method, method, headers, config)

          {_method, []} ->
            check_simple(request_origin, method, headers, config)
        end

        #
        # _ ->
        #   raise ArgumentError, "More than one header found for `#{name}`"
    end
  end

  defp check_preflight(request_origin, request_method, _, _, config) do
    case check_origin(request_origin, config.origins) do
      {:ok, allow_origin} ->
        case check_method(request_method, config.allow_methods) do
          # What do you put if Any method is allowed
          {:ok, allow_methods} ->
            {:ok,
             {:preflight,
              [
                {"access-control-allow-origin", allow_origin},
                {"access-control-allow-methods", Enum.join(allow_methods, ", ")}
              ]}}

          {:error, reason} ->
            {:error, {:preflight, reason}}
        end

      {:error, reason} ->
        {:error, {:preflight, reason}}
    end
  end

  defp check_simple(request_origin, method, _, config) do
    case check_origin(request_origin, config.origins) do
      {:ok, allow_origin} ->
        case check_method("#{method}", config.allow_methods) do
          # Simple request does not need to expose allow method
          {:ok, _allow_methods} ->
            {:ok,
             {:simple,
              [
                {"access-control-allow-origin", allow_origin}
              ]}}

          {:error, reason} ->
            {:error, {:simple, reason}}
        end
    end
  end

  defp check_origin(request_origin, [request_origin]) do
    {:ok, request_origin}
  end

  defp check_origin(request_origin, :any) do
    {:ok, request_origin}
  end

  defp check_origin(_, _) do
    {:error, :invalid_origin}
  end

  defp check_method(request_method, methods) when is_binary(request_method) do
    if request_method in (methods ++ ["GET", "HEAD", "POST"]) do
      {:ok, methods}
    else
      {:error, :invalid_method}
    end
  end

  # TODO function list regex
end
