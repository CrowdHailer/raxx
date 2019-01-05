defmodule Raxx.Middlewares.CORS do
  use Raxx.Middleware

  # vary header appear twice? I think ok
  @impl Raxx.Middleware
  def process_head(request, config, next) do
    case CORS.check(request.method, request.headers, config) do
      {:ok, :no_cors} ->
        continue_processing(request, [], next)

      {:ok, {:simple, additional_headers}} ->
        continue_processing(request, additional_headers, next)

      {:error, {:simple, _reason}} ->
        # I'm surprised this doesn't halt
        continue_processing(request, [], next)

      {:ok, {:preflight, headers}} ->
        %{Raxx.response(:ok) | headers: headers}

      {:error, {:preflight, _reason}} ->
        {:halt, []}
    end
  end

  defp continue_processing(request, additional_headers, next) do
    {parts, next} = Raxx.Server.handle_head(next, request)
    parts = modify_response_parts(parts, additional_headers)
    {parts, additional_headers, next}
  end

  @impl Raxx.Middleware
  def process_data(data, additional_headers, next) do
    {parts, next} = Raxx.Server.handle_data(next, data)
    parts = modify_response_parts(parts, additional_headers)
    {parts, additional_headers, next}
  end

  @impl Raxx.Middleware
  def process_tail(tail, additional_headers, next) do
    {parts, next} = Raxx.Server.handle_tail(next, tail)
    parts = modify_response_parts(parts, additional_headers)
    {parts, additional_headers, next}
  end

  @impl Raxx.Middleware
  def process_info(info, additional_headers, next) do
    {parts, next} = Raxx.Server.handle_info(next, info)
    parts = modify_response_parts(parts, additional_headers)
    {parts, additional_headers, next}
  end

  defp modify_response_parts(parts, additional_headers) do
    Enum.map(parts, fn
      response = %Raxx.Response{headers: headers} ->
        %{response | headers: headers ++ additional_headers}

      other ->
        other
    end)
  end
end
