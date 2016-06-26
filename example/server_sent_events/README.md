# ServerSentEvents

**Example Raxx application with a subscription to server sent events**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `server_sent_events` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:server_sent_events, "~> 0.1.0"}]
    end
    ```

  2. Ensure `server_sent_events` is started before your application:

    ```elixir
    def application do
      [applications: [:server_sent_events]]
    end
    ```
