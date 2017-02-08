# Ace.HTTP

**HTTP Server built on top of Ace TCP connection manager**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `ace_http` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ace_http, "~> 0.1.2"}]
    end
    ```

  2. Ensure `ace_http` is started before your application:

    ```elixir
    def application do
      [applications: [:ace_http]]
    end
    ```
