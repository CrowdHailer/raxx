# Raxx.Elli

**Elli adapter for the Raxx webserver interface**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `raxx_elli` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx_elli, "~> 0.1.0"}]
    end
    ```

  2. Ensure `raxx_elli` is started before your application:

    ```elixir
    def application do
      [applications: [:raxx_elli]]
    end
    ```

## Usage

[HelloElli example](https://github.com/CrowdHailer/raxx/tree/master/example/hello_elli)
