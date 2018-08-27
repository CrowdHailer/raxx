defmodule Raxx.SimpleClient do
  @moduledoc ~S"""
  A very simple HTTP/1.1 client.

  This client makes very few assumptions about how to send requests.
  i.e. Each request is sent over a new connection, no HTTP/1.1 pipelining.

  This makes it ideal for testing servers

  ## Usage

  Build a request using the helpers available in `Raxx` module.

      request = Raxx.request(:GET, "http://example.com")
      |> Raxx.set_header("accept", "text/html")

  #### Send the request asynchronously

  A channel is returned to be used to then wait for a response when needed.

      channel = Raxx.SimpleClient.send_async(request)

  Wait for a response on the channel.

      {:ok, response} = Raxx.SimpleClient.yield(channel, 2_000)

  #### Send the request synchronously

      {:ok, response} = Raxx.SimpleClient.send_sync(request, 2_000)
  """
  use GenServer

  alias __MODULE__.Channel

  @typedoc """
  A reference to a running client process that can be used to yield or shutdown the request
  """
  @type channel :: %Channel{
          caller: pid,
          reference: reference,
          request: Raxx.Request.t(),
          client: pid
        }

  @enforce_keys [
    :request,
    :reference,
    :caller,
    :monitor,
    :socket,
    :buffer,
    :response,
    :body,
    :body_buffer
  ]

  defstruct @enforce_keys

  # There could be an async_supervised that took a DynamicSupervisor pid as argument.
  # This would mean the client process does not need to be linked to the caller.
  # I can't however think of a reason when that would actually be useful.
  # If the caller dies the client has no place to send the response.
  # Also the dynamic supervisor could become a bottleneck.

  # A client (or gateway) that limited total number of connections, or managed sessions,
  # could easily make use of send_async.
  # A coordination process could use send_async but pass a different caller.
  # Then as long as that channel was passed to the caller, the client could do it?
  # then yielding from that caller would work.

  @doc """
  Send a request over a new channel.

  **NOTE:** Request streaming is not supported, so the request sent must be complete,
  i.e. have a full binary body or no body.
  """
  @spec send_async(Raxx.Request.t()) :: channel
  def send_async(%Raxx.Request{body: true}) do
    raise ArgumentError, "Request had body `true`, client can only send complete requests."
  end

  def send_async(request = %Raxx.Request{}) do
    caller = self()
    reference = make_ref()
    # max_body_size = Keyword.get(options, max_body_length)

    # All match errors are this point come from bad arguments,
    # and can therefore raise errors
    {:ok, client} = GenServer.start_link(__MODULE__, {request, reference, caller})

    %Channel{
      caller: caller,
      reference: reference,
      request: request,
      client: client
    }
  end

  @doc """
  Send a request and wait for the response.

  This function handles shutting down the client in case of a timeout.
  """
  def send_sync(request, timeout) do
    channel = send_async(request)

    case yield(channel, timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, :timeout} ->
        {:ok, maybe_response} = shutdown(channel, 1000)

        if maybe_response do
          {:ok, maybe_response}
        else
          {:error, :timeout}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Await the response from the given channel.

  **NOTE:** A response can only be yielded once, it checks the process mailbox for the response.

  **NOTE:** If yielding returns `{:error, :timeout}` then a response could be received in the future.
  To ensure in this case that there is no message left in the mailbox, run `shutdown/2` after yield.
  """
  @spec yield(channel, integer) :: {:ok, Raxx.Response.t()} | {:error, :timeout | {:exit, term}}
  def yield(channel = %Channel{caller: caller}, _timeout) when caller != self() do
    raise ArgumentError, invalid_caller_error(channel)
  end

  def yield(%Channel{reference: reference, client: client}, timeout) do
    monitor = Process.monitor(client)

    receive do
      {^reference, response} ->
        Process.demonitor(monitor, [:flush])
        response

      {:DOWN, ^monitor, _, _, reason} ->
        {:error, {:exit, reason}}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  @doc """
  Shutdown a running channel.

  If the response was already available when client is shutdown then it is returned.
  This can be used if a response is wanted immediatly.

      channel = Raxx.SimpleClient.send_async(request)
      # Do something slow
      {:ok, maybe_response} = Raxx.SimpleClient.shutdown(request, 1000)
      if response do
        # Look, a response
      end

  **NOTE:** timeout is allowed maximum for process to exit.
  It is not time waiting for a response.
  """
  @spec shutdown(channel, integer) :: {:ok, Raxx.Response.t() | nil} | {:error, pid}
  def shutdown(channel = %Channel{caller: caller}, _timeout) when caller != self() do
    raise ArgumentError, invalid_caller_error(channel)
  end

  def shutdown(%Channel{reference: reference, client: client}, timeout) do
    monitor = Process.monitor(client)
    :ok = GenServer.cast(client, :shutdown)

    receive do
      {:DOWN, ^monitor, _, _, _reason} ->
        response =
          receive do
            {^reference, {:ok, response}} ->
              response

            {^reference, _} ->
              nil
          after
            0 ->
              nil
          end

        {:ok, response}
    after
      timeout ->
        {:error, client}
    end
  end

  @impl GenServer
  def init({request, reference, caller}) do
    monitor = Process.monitor(caller)

    state = %__MODULE__{
      request: request,
      reference: reference,
      caller: caller,
      monitor: monitor,
      socket: nil,
      buffer: "",
      response: nil,
      body: nil,
      body_buffer: ""
    }

    :do_send = send(self(), :do_send)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:do_send, state = %__MODULE__{socket: nil}) do
    case connect(target(state.request), 1_000) do
      {:ok, socket} ->
        case Raxx.HTTP1.serialize_request(state.request, connection: :close) do
          {head, {:complete, body}} ->
            :ok = send_data(socket, [head, body])

            :ok = set_active(socket)
            state = %{state | socket: socket}
            {:noreply, state}
        end

      {:error, reason} ->
        send(state.caller, {state.reference, {:error, reason}})
        {:stop, :normal, state}
    end
  end

  def handle_info(
        {transport, raw_socket, packet},
        state = %{socket: {transport, raw_socket}}
      )
      when transport in [:tcp, :ssl] do
    handle_packet(packet, state)
  end

  def handle_info({transport_closed, raw_socket}, state = %{socket: {_transport, raw_socket}})
      when transport_closed in [:tcp_closed, :ssl_closed] do
    send(state.caller, {state.reference, {:error, :closed}})

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_cast(:shutdown, state) do
    :ok = close(state.socket)
    {:stop, :normal, state}
  end

  defp handle_packet(packet, state = %{response: nil}) do
    buffer = state.buffer <> packet

    case Raxx.HTTP1.parse_response(buffer) do
      {:ok, {response, _connection_status, body_read_state, rest}} ->
        state = %{state | response: response, body: body_read_state, buffer: rest}

        case state.request.method do
          :HEAD ->
            response = %{response | body: ""}
            send(state.caller, {state.reference, {:ok, response}})
            {:stop, :normal, state}

          _method ->
            handle_packet("", state)
        end

      {:more, :undefined} ->
        state = %{state | buffer: buffer}
        :ok = set_active(state.socket)
        {:noreply, state}

      {:error, reason} ->
        send(state.caller, {state.reference, {:error, reason}})
        {:stop, :normal, state}
    end
  end

  defp handle_packet(_packet, state = %{body: {:complete, body}}) do
    response = %{state.response | body: body}
    send(state.caller, {state.reference, {:ok, response}})
    {:stop, :normal, state}
  end

  defp handle_packet(packet, state = %{body: {:bytes, bytes}}) do
    case state.buffer <> packet do
      <<body::binary-size(bytes), rest::binary>> ->
        response = %{state.response | body: body}
        send(state.caller, {state.reference, {:ok, response}})

        state = %{state | buffer: rest}
        {:stop, :normal, state}

      buffer ->
        state = %{state | buffer: buffer}
        :ok = set_active(state.socket)
        {:noreply, state}
    end
  end

  defp handle_packet(packet, state = %{body: :chunked}) do
    case Raxx.HTTP1.parse_chunk(state.buffer <> packet) do
      {:ok, {"", rest}} ->
        response = %{state.response | body: state.body_buffer}
        send(state.caller, {state.reference, {:ok, response}})

        state = %{state | buffer: rest}
        {:stop, :normal, state}

      {:ok, {nil, rest}} ->
        state = %{state | buffer: rest}
        :ok = set_active(state.socket)
        {:noreply, state}

      {:ok, {chunk, rest}} ->
        state = %{state | body_buffer: state.body_buffer <> chunk, buffer: rest}
        handle_packet("", state)
    end
  end

  # The intention is to make the target overridable in future versions.
  # This will allow requests with different hosts to be sent for test cases.
  defp target(request) do
    scheme = request.scheme
    host = :erlang.binary_to_list(Raxx.request_host(request))
    port = Raxx.request_port(request)

    {scheme, host, port}
  end

  defp invalid_caller_error(channel = %Channel{}) do
    "Channel #{inspect(channel)} must be queried from the calling process, but was queried from #{
      inspect(self())
    }"
  end

  defp connect({:http, host, port}, timeout) do
    options = [mode: :binary, packet: :raw, active: false]

    case :gen_tcp.connect(host, port, options, timeout) do
      {:ok, raw_socket} ->
        {:ok, {:tcp, raw_socket}}

      other ->
        other
    end
  end

  defp connect({:https, host, port}, timeout) do
    options = [mode: :binary, packet: :raw, active: false]

    case :ssl.connect(host, port, options, timeout) do
      {:ok, raw_socket} ->
        {:ok, {:ssl, raw_socket}}

      other ->
        other
    end
  end

  defp set_active({:tcp, socket}) do
    :inet.setopts(socket, active: :once)
  end

  defp set_active({:ssl, socket}) do
    :ssl.setopts(socket, active: :once)
  end

  defp send_data({:tcp, socket}, message) do
    :gen_tcp.send(socket, message)
  end

  defp send_data({:ssl, socket}, message) do
    :ssl.send(socket, message)
  end

  defp close({:tcp, socket}) do
    :gen_tcp.close(socket)
  end

  defp close({:ssl, socket}) do
    :ssl.close(socket)
  end
end
