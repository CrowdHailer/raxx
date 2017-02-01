defmodule Raxx.Adapters.Elli.RequestTest do
  use Raxx.Verify.RequestCase

  setup do
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Adapters.Elli.Handler,
      callback_args: {Raxx.Verify.Forwarder, %{target: self()}},
      port: 2020]
    {:ok, %{port: 2020}}
  end

end
