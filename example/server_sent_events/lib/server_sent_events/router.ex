defmodule ServerSentEvents.Router do
  import Raxx.Response
  import Raxx.ServerSentEvents

  def call(%{path: [], method: "GET"}, _opts) do
    ok(home_page)
  end

  def call(%{path: ["events"], method: "GET"}, opts) do
    upgrade(opts, __MODULE__)
  end

  def call(_request, _opts) do
    not_found("Page not found")
  end

  def open(_options) do
    Process.send_after(self, 0, 1000)
    event("hello")
  end

  def info(10, _opts) do
    close()
  end
  def info(i, _opts) when rem(i, 2) == 0 do
    Process.send_after(self, i + 1, 1000)
    event(Integer.to_string(i))
  end
  def info(i, _opts) do
    Process.send_after(self, i + 1, 1000)
    no_event
  end

  defp home_page do
    """
<!DOCTYPE html>
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
				var source = new EventSource('/events');
        source.onmessage = function(e){
          console.log(e)
        }
				source.addEventListener('message', function(event) {
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

      addStatus("banana")
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
end
