# Raxx

**Interface for HTTP webservers, frameworks and clients.**

[![Hex pm](http://img.shields.io/hexpm/v/raxx.svg?style=flat)](https://hex.pm/packages/raxx)
[![Build Status](https://secure.travis-ci.org/CrowdHailer/raxx.svg?branch=master
"Build Status")](https://travis-ci.org/CrowdHailer/raxx)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

- [Install from hex.pm](https://hex.pm/packages/raxx)
- [Documentation available on hexdoc](https://hexdocs.pm/raxx)
- [Discuss on slack](https://elixir-lang.slack.com/messages/C56H3TBH8/)

See [Raxx.Kit](https://github.com/CrowdHailer/raxx_kit) for a project generator that helps you set up
a web project based on [Raxx](https://github.com/CrowdHailer/raxx)/[Ace](https://github.com/CrowdHailer/Ace).

## Simple server

#### 1. Defining a server

```elixir
defmodule MyServer do
  use Raxx.SimpleServer

  @impl Raxx.SimpleServer
  def handle_request(%{method: :GET, path: []}, _state) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body("Hello, World!")
  end

  def handle_request(%{method: :GET, path: _}, _state) do
    response(:not_found)
    |> set_header("content-type", "text/plain")
    |> set_body("Oops! Nothing here.")
  end
end
```

- *A request's path is split into segments.
  A request to `GET /` has path `[]`.*

#### 2. Running a server

To start a Raxx server a compatible HTTP server is needed.
This example uses [Ace](https://github.com/crowdhailer/ace) that can serve both HTTP/1 and HTTP/2.

```elixir
raxx_server = {MyServer, nil}
http_options = [port: 8080, cleartext: true]

{:ok, pid} = Ace.HTTP.Service.start_link(raxx_server, http_options)
```

- *The second element in the Raxx server tuple is passed as the second argument to the `handle_request/2` callback.
  In this example it is unused and so set to nil.*

Start your project and visit [http://localhost:8080](http://localhost:8080).

## HTTP streaming

An HTTP exchange involves a client sending data to a server receiving a response.
A simple view is to model this as a single message sent in each direction.
*Working with this model corresponds to `Raxx.SimpleServer` callbacks.*

```txt
           request -->
Client ============================================ Server
                                   <-- response
```

When the simple model is insufficient Raxx exposes a lower model.
This consists of a series of messages in each direction.
*Working with this model corresponds to `Raxx.Server` callbacks.*

```txt
           tail | data(1+) | head(request) -->
Client ============================================ Server
           <-- head(response) | data(1+) | tail
```

- *The body of a request or a response, is the combination of all data parts sent.*

#### Stateful server

The `LongPoll` server is stateful.
After receiving a complete request this server has to wait for extra input before sending a response to the client.

```elixir
defmodule LongPoll do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(%{method: :GET, path: ["slow"]}, state) do
    Process.send_after(self(), :reply, 30_000)

    {[], state}
  end

  @impl Raxx.Server
  def handle_info(:reply, _state) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body("Hello, Thanks for waiting.")
  end
end
```
- *A long lived server needs to return two things; the message parts to send, in this case nothing `[]`;
  and the new state of the server, in this case no change `state`.*
- *The `initial_state` is configured when the server is started.*

#### Server streaming

The `SubscribeToMessages` server streams its response.
The server will send the head of the response upon receiving the request.
Data is sent to the client, as part of the body, when it becomes available.
The response is completed when the chatroom sends a `:closed` message.

```elixir
defmodule SubscribeToMessages do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(%{method: :GET, path: ["messages"]}, state) do
    {:ok, _} = ChatRoom.join()
    outbound = response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(true)

    {[outbound], state}
  end

  @impl Raxx.Server
  def handle_info({ChatRoom, :closed}, state) do
    outbound = tail()

    {[outbound], state}
  end

  def handle_info({ChatRoom, data}, state) do
    outbound = data(data)

    {[outbound], state}
  end
end
```
- *Using `set_body(true)` marks that the response has a body that it is not yet known.*
- *A stream must have a tail to complete, metadata added here will be sent as trailers.*

#### Client streaming

The `Upload` server writes data to a file as it is received.
Only once the complete request has been received is a response sent.

```elixir
defmodule Upload do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(%{method: :PUT, path: ["upload"] body: true}, _state) do
    {:ok, io_device} = File.open("my/path")
    {[], {:file, device}}
  end

  @impl Raxx.Server
  def handle_data(data, state = {:file, device}) do
    IO.write(device, data)
    {[], state}
  end

  @impl Raxx.Server
  def handle_tail(_trailers, state) do
    response(:see_other)
    |> set_header("location", "/")
  end
end
```
- *A body may arrive split by packets, chunks or frames.
  `handle_data` will be invoked as each part arrives.
  An application should never assume how a body will be broken into data parts.*

#### Request/Response flow

It is worth noting what guarantees are given on the request parts passed to the
Server's `handle_*` functions. It depends on the Server type,
`Raxx.Server` vs `Raxx.SimpleServer`:

<!-- NOTE: diagram svg files contain the source diagram and can be edited using draw.io -->
![request flow](assets/request_flow.svg)

So, for example, after a `%Raxx.Request{body: false}` is passed to a Server's `c:Raxx.Server.handle_head/2`
callback, no further request parts will be passed to to the server (`c:Raxx.Server.handle_info/2`
messages might be, though).

Similarly, these are the valid sequences of the response parts returned from the Servers:

<!-- NOTE: diagram svg files contain the source diagram and can be edited using draw.io -->
![response flow](assets/response_flow.svg)

Any `Raxx.Middleware`s should follow the same logic.

#### Router

The `Raxx.Router` can be used to match requests to specific server modules.

```elixir
defmodule MyApp do
  use Raxx.Server

  use Raxx.Router, [
    {%{method: :GET, path: []}, HomePage},
    {%{method: :GET, path: ["slow"]}, LongPoll},
    {%{method: :GET, path: ["messages"]}, SubscribeToMessages},
    {%{method: :PUT, path: ["upload"]}, Upload},
    {_, NotFoundPage}
  ]
end
```
