defmodule ServerSentEvents.Router do
  import Raxx.Response

  def call(%{path: [], method: "GET"}, _opts) do
    ok(home_page)
  end

  def call(%{path: ["sse"], method: "GET"}, _opts) do
    {:upgrade, "cool"}
  end

  def call(_request, _opts) do
    not_found("Page not found")
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
				var source = new EventSource('/sse');
				source.addEventListener('message', function(event) {
					addStatus("server sent the following: '" + event.data + "'");
					}, false);
					source.addEventListener('open', function(event) {
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
