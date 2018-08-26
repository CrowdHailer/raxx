defmodule Raxx.NaiveClient do
  @moduledoc ~S"""

  When starting a client,
  for the caller to be able to send the monitor as reference a secondary call must be made
  We could send a different reference to the monitor.

  init can use proc_lib.init_ack to send back a value in addition to the pid

  handle_call {:async, request} can use GenServer.reply

  Goal is to have a start_link that can be easily supervised

  start_link(request: request, target: target)

  Need to pass arguments like max headers etc

  child_spec can do something clever to not not start monitors under supervisor
  # Don't start monitor until yielding
  This is confusing because if started supervised then the caller information can be lost
  {:ok, pid, task} = Client.start_link(request, )
  Client.yield()
  what about when yield times out.
  Message needs clearing up
  """
  use GenServer

  @enforce_keys [
    :request,
    :reference,
    :caller,
    :monitor,
    :socket,
    :buffer,
    :response,
    :body
  ]

  defstruct @enforce_keys

  defmodule Exchange do
    @enforce_keys [
      :caller,
      :reference,
      # NOTE sure request is needed in exchange struct
      :request,
      :client
    ]
    defstruct @enforce_keys
  end

  # Can be called by supervisor or normal process
  defp start_link(request, reference, caller) do
    #   # caller = Keyword.get(options, :caller, self())
    #   # max_body_size = Keyword.get(options, max_body_length)
    GenServer.start_link(__MODULE__, {request, reference, caller})
  end

  def async(request, _options \\ []) do
    caller = self()
    reference = make_ref()

    case start_link(request, reference, caller) do
      {:ok, client} ->
        exchange = %Exchange{
          caller: caller,
          reference: reference,
          request: request,
          client: client
        }

        {:ok, exchange}
    end
  end

  # TODO raise error if not caller
  def yield(%Exchange{reference: reference, client: client}, timeout) do
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
  return {:ok, nil or response}, or exit pid
  """
  def shutdown(_task) do
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
      body: nil
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
    end
  end

  def handle_info(
        {transport, raw_socket, packet},
        state = %{socket: {transport, raw_socket}}
      )
      when transport in [:tcp, :ssl] do
    handle_packet(packet, state)
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

  # The intention is to make the target overridable in future versions.
  # This will allow requests with different hosts to be sent for test cases.
  defp target(request) do
    scheme = request.scheme
    host = :erlang.binary_to_list(Raxx.request_host(request))
    port = Raxx.request_port(request)

    {scheme, host, port}
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

  # defp close({:tcp, socket}) do
  #   :gen_tcp.close(socket)
  # end
  #
  # defp close({:ssl, socket}) do
  #   :ssl.close(socket)
  # end
end