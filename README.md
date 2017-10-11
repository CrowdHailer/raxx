# Raxx

**Interface for HTTP webservers and frameworks.
Supports server, client and bidirectional streaming.**

- [Install from hex.pm](https://hex.pm/packages/raxx)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx)

### Hello World!

```elixir
defmodule MyApp.WW do
  use Raxx.Server

  @impl Raxx.Server
  def handle_request(_request, _config) do
    Raxx.response(:ok)
    |> Raxx.set_header("content-type", "text/plain")
    |> Raxx.set_body("Hello, World!")
  end
end
```

*Simplest example where the client sends a single request to the server and gets a single response back.*

```elixir
defmodule MyApp.Echo do
  use Raxx.Server

  @impl Raxx.Server
  def handle_headers(_request, state) do
    outbound = Raxx.response(:ok)
    |> Raxx.set_body(true)

    {[outbound], state}
  end

  @impl Raxx.Server
  def handle_fragment(data, state) do
    outbound = Raxx.fragment(data)

    {[outbound], state}
  end

  @impl Raxx.Server
  def handle_trailers(_trailers, state) do
    outbound = Raxx.trailer()

    {[outbound], state}
  end
end
```

`Raxx.Server` specifies  

## Community

- [elixir-lang slack channel](https://elixir-lang.slack.com/messages/C56H3TBH8/)
- [FAQ](FAQ.md)

## Testing

To work with Raxx locally Elixir 1.4 or greater must be [installed](https://elixir-lang.org/install.html).

```
git clone git@github.com:CrowdHailer/raxx.git
cd raxx

mix deps.get
mix test
```
