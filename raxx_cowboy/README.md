# Raxx.Cowboy

**Cowboy adapter for the raxx webserver interface**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `raxx_cowboy` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx_cowboy, "~> 0.2.0"}]
    end
    ```

  2. Ensure `raxx_cowboy` is started before your application:

    ```elixir
    def application do
      [applications: [:raxx_cowboy]]
    end
    ```

## Usage

[cowboy example](https://github.com/CrowdHailer/raxx/tree/master/example/cowboy_example)
