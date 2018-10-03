defmodule Raxx.Head do
  @behaviour Raxx.Server

  def wrap(next, _options \\ []) do
    {__MODULE__, {:unset, next}}
  end

  def handle_head(request, {:unset, next}) do
    switched = request.method == :HEAD

    request =
      if switched do
        %{request | method: :GET}
      else
        request
      end

    Raxx.Server.handle_head(next, request)
    |> handle_next(switched)
  end

  def handle_data(data, {switched, next}) do
    Raxx.Server.handle_data(next, data)
    |> handle_next(switched)
  end

  def handle_tail(tail, {switched, next}) do
    Raxx.Server.handle_tail(next, tail)
    |> handle_next(switched)
  end

  def handle_info(info, {switched, next}) do
    Raxx.Server.handle_info(next, info)
    |> handle_next(switched)
  end

  defp handle_next({parts, next}, switched) do
    parts = modify_parts(parts, switched)
    {parts, {switched, next}}
  end

  defp modify_parts(parts, false) do
    parts
  end

  # response will always be first part, don't need to check the rest
  defp modify_parts([response = %Raxx.Response{} | _rest], true) do
    [%{response | body: false}]
  end

  # The worker should shutdown after seeing the last part so we should not see any other case here.
  def handle_request(_, _) do
    raise "Should not be here!"
  end
end
