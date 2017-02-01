# Raxx.Static

**Static file serving in Raxx applications**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `raxx_static` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:raxx_static, "~> 0.1.0"}]
    end
    ```

  2. Ensure `raxx_static` is started before your application:

    ```elixir
    def application do
      [applications: [:raxx_static]]
    end
    ```

## Usage

```elixir
defmodule StaticFileServer do
  require Raxx.Static

  # relative path to assets directory
  dir = "./static"
  Raxx.Static.serve_dir(dir)
end
```

TODO serve single file example
