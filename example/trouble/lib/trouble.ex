defmodule Trouble do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(:elli, [[
        callback: Raxx.Adapters.Elli.Handler,
        callback_args: {Raxx.ErrorHandler, %{next: __MODULE__, app: :trouble}},
        port: 8080]])
    ]

    opts = [strategy: :one_for_one, name: Trouble.Supervisor]
    Supervisor.start_link(children, opts)
  end

  import Raxx.Response

  def handle_request(%{path: []}, _env) do
    ok("Hello, World!")
  end

  def handle_request(%{path: ["throw"]}, _env) do
    throw :bad
  end
  def handle_request(%{path: ["exception"]}, _env) do
    __MODULE__.ouch(1,2)
    # Raxx.Response.ok(1, 2, 3)
    1/0
  end

  def ouch do
    Raxx.Response.ok
  end

  def handle_request(%{path: _unknown}, _env) do
    not_found()
  end
end
