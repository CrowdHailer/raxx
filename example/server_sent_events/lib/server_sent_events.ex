defmodule MyHandler do
  def init({:tcp, :http}, req, opts) do
    {:ok, resp} = :cowboy_req.reply(200, [], body, req)
    {:ok, resp, opts}
  end

  def body do
    """
  <!DOCTYPE html>
  <meta charset="utf-8"/>
  <html>
  <head>
    <script type="text/javascript">
      function ready() {
        if (!!window.EventSource) {
          setupEventSource();
        } else {
          document.getElementById('status').innerHTML =
            "Sorry but your browser doesn't support the EventSource API";
        }
      }
      function setupEventSource() {
        var source = new EventSource('/sse');
        source.onmessage = function(e){
          console.log(e)
        }
        source.addEventListener('message', function(event) {
            console.log(event)
          addStatus("server sent the following: '" + event.data + "'");
          }, false);
          source.addEventListener('open', function(event) {
            console.log(event)
            addStatus('eventsource connected.')
          }, false);
          source.addEventListener('error', function(event) {
            if (event.eventPhase == EventSource.CLOSED) {
              addStatus('eventsource was closed.')
            }
          }, false);
      }
      function addStatus(text) {
        var date = new Date();
        document.getElementById('status').innerHTML
        = document.getElementById('status').innerHTML
        + date + ": " + text + "<br/>";
      }
      setTimeout(function(){

      addStatus("blueberry")
        }, 1000)
    </script>
  </head>
  <body onload="ready();">
    Hi!
    <div id="status"></div>
  </body>
  </html>
    """
  end

  def handle(req, state) do
    {:ok, req, state}
  end

  def terminate(reason, req, state) do
    :ok
  end
end

defmodule SSEHandler do
  def init(transport, req, opts) do
    IO.inspect(transport)
    IO.inspect(req)
    IO.inspect(opts)
    {:ok, req1} = :cowboy_req.chunked_reply(200, [{"content-type", "text/event-stream"}], req)
    :timer.sleep(1000)
    :cowboy_req.chunk("data: my message\n\n", req1)
    :timer.sleep(1000)
    # :cowboy_req.chunk("", req1)
    :timer.sleep(1000)
    :timer.sleep(100_000)
    {:ok, req1, opts}
  end

  def loop(message, req, state) do

  end

  def handle(req, state) do
    {:ok, req, state}
  end

  def terminate(reason, req, state) do
    :ok
  end
end

defmodule ServerSentEvents do
  use Application

  def start(_type, _args) do
    routes = [
      {"/", MyHandler, :no_state},
      {"/sse", SSEHandler, :no_state}
      # {:_, Raxx.Adapters.Cowboy.Handler, {ServerSentEvents.Router, %{}}}

    ]

    dispatch = :cowboy_router.compile([{:_, routes}])

    opts = [port: 8080]
    env = [dispatch: dispatch]

    # Don't forget can set any name
    {:ok, _pid} = :cowboy.start_http(:http, 100, opts, [env: env])
  end
end
