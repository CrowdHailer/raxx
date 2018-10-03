defmodule Raxx.MethodOverride do
  @behaviour Raxx.Server

  def wrap(next, _options) do
    {__MODULE__, {:unset, next}}
  end

  def handle_head(request, {:unset, next}) do
    switched = request.method == :HEAD

    Server.handle_head(request, next)
    |> handle_next(switched)
  end

  def handle_data(data, next) do
    Server.handle_data(data, next)
    |> handle_next(switched)
  end

  def handle_tail(tail, next) do
    Server.handle_tail(tail, next)
    |> handle_next(switched)
  end

  def handle_info(info, next) do
    Server.handle_info(info, next)
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
end
