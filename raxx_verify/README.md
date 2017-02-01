# Raxx.Verify

**Verify that Server adapters are correctly implementing a Raxx Interface**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `raxx_verify` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx_verify, "~> 0.1.0"}]
    end
    ```

  2. Ensure `raxx_verify` is started before your application:

    ```elixir
    def application do
      [applications: [:raxx_verify]]
    end
    ```
