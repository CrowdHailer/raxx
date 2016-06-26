defmodule Raxx.ServerSentEvents do
  def upgrade(options, handler) do
    %{
      upgrade: __MODULE__,
      handler: handler,
      options: options
    }
  end

  def no_event do
    :noevent
  end

  def event(data) when is_binary(data) do
    {:event, data}
  end

  def close() do
    :close
  end
end
