defmodule Plugger.Router do
  use Plug.Router

   use Plug.Debugger, otp_app: :foggy

   plug :match
   plug :dispatch

   get "/throw" do
     throw :arrrr
   end
   get "/exception" do
     Enum.map([], 1, 6, 9)
   end

   match _ do
     send_resp(conn, 200, "Hello from plug")
   end
end

defmodule PlugExample do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Plugger.Router, [], [
        dispatch: dispatch,
        port: 8080
        ])
      ]

      opts = [strategy: :one_for_one, name: Navis.Supervisor]
      Supervisor.start_link(children, opts)
    end

    defp dispatch do
      [
        {:_, [
          # {"/ws", Plugger.SocketHandler, []},
          {:_, Plug.Adapters.Cowboy.Handler, {Plugger.Router, []}}
          ]}
        ]
      end
    end
