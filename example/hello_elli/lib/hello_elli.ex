defmodule HelloElli do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(:elli, [[
        callback: Raxx.Adapters.Elli.Handler,
        callback_args: {__MODULE__, %{}},
        port: 8080]])
    ]

    opts = [strategy: :one_for_one, name: HelloElli.Supervisor]
    Supervisor.start_link(children, opts)
  end

  import Raxx.Response

  def handle_request(%{path: []}, _env) do
    ok("Hello, World!")
  end

  def handle_request(%{path: [name]}, _env) do
    ok("Hello, #{name}!")
  end

  def handle_request(%{path: _unknown}, _env) do
    not_found()
  end
end
