# RaxxServerSentEvents

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `raxx_server_sent_events` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx_server_sent_events, "~> 0.1.0"}]
    end
    ```

  2. Ensure `raxx_server_sent_events` is started before your application:

    ```elixir
    def application do
      [applications: [:raxx_server_sent_events]]
    end
    ```

See sever sent events in examples directory.

```elixir
defmodule ServerSentEvents.Router do
  alias Raxx.Response
  alias Raxx.ServerSentEvents, as: SSE

  def handle_request(%{path: [], method: :GET}, _opts) do
    Response.ok(home_page)
  end

  def handle_request(%{path: ["events"], method: :GET}, env) do
    Process.send_after(self, 0, 1000)
    SSE.upgrade(__MODULE__, env, %{initial: "hello"})
  end

  def handle_request(_request, _opts) do
    Response.not_found("Page not found")
  end

  # handle_info
  def handle_info(10, _opts) do
    {:send, ""}
  end
  def handle_info(i, _opts) when rem(i, 2) == 0 do
    Process.send_after(self, i + 1, 1000)
    chunk = SSE.Event.new("#{i}", event: "count") |> SSE.Event.to_chunk
    {:send, chunk}
  end
  def handle_info(i, _opts) do
    Process.send_after(self, i + 1, 1000)
    :nosend
  end

  defp home_page do
    """
    The page. see example.
    """
  end
end
```

[Link to implementing server in node.js](http://www.html5rocks.com/en/tutorials/eventsource/basics/)

[HTML living standard](https://html.spec.whatwg.org/multipage/comms.html#server-sent-events)
