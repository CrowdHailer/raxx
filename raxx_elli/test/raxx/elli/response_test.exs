defmodule Raxx.Elli.ResponseTest do
  use Raxx.Verify.ResponseCase

  setup do
    port = 2022
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Elli.Handler,
      callback_args: {__MODULE__, %{target: self()}},
      port: port]
    {:ok, %{port: port}}
  end

end
