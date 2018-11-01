defmodule Raxx.Stack do
  alias Raxx.Server
  alias Raxx.Middleware

  @behaviour Server

  @moduledoc """
  A `Raxx.Stack` is a list of `Raxx.Middleware`s attached to a `Raxx.Server`.
  It implements the `Raxx.Server` interface itself so it can be used anywhere
  "normal" server can be.
  """

  defmodule State do
    @moduledoc false

    @enforce_keys [:middlewares, :server]
    defstruct @enforce_keys

    # DEBT: compare struct t() performance to a (tagged) tuple implementation
    @type t :: %__MODULE__{
            middlewares: [Middleware.t()],
            server: Server.t()
          }

    def new(middlewares \\ [], server) when is_list(middlewares) do
      %__MODULE__{
        middlewares: middlewares,
        server: server
      }
    end

    def get_server(%__MODULE__{server: server}) do
      server
    end

    def set_server(state = %__MODULE__{}, {_, _} = server) do
      %__MODULE__{state | server: server}
    end

    def get_middlewares(%__MODULE__{middlewares: middlewares}) do
      middlewares
    end

    def set_middlewares(state = %__MODULE__{}, middlewares) when is_list(middlewares) do
      %__MODULE__{state | middlewares: middlewares}
    end

    @spec push_middleware(t(), Middleware.t()) :: t()
    def push_middleware(state = %__MODULE__{middlewares: middlewares}, middleware) do
      %__MODULE__{state | middlewares: [middleware | middlewares]}
    end

    @spec pop_middleware(t()) :: {Middleware.t() | nil, t()}
    def pop_middleware(state = %__MODULE__{middlewares: middlewares}) do
      case middlewares do
        [] ->
          {nil, state}

        [topmost | rest] ->
          {topmost, %__MODULE__{state | middlewares: rest}}
      end
    end
  end

  @typedoc """
  The internal state of the `Raxx.Stack`.

  Its structure shouldn't be relied on, it is subject to change without warning.
  """
  @opaque state :: State.t()

  @typedoc """
  Represents a pipeline of middlewares attached to a server.

  Can be used exactly as any `t:Raxx.Server.t/0` could be.
  """
  @type t :: {__MODULE__, state()}

  ## Public API

  @doc """
  Creates a new stack from a list of middlewares and a server.
  """
  @spec new([Middleware.t()], Server.t()) :: t()
  def new(middlewares \\ [], server) when is_list(middlewares) do
    {__MODULE__, State.new(middlewares, server)}
  end

  @doc """
  Replaces the server in the stack.
  """
  @spec set_server(t(), Server.t()) :: t()
  def set_server({__MODULE__, state}, server) do
    {__MODULE__, State.set_server(state, server)}
  end

  @doc """
  Returns the server contained in the stack.
  """
  @spec get_server(t()) :: Server.t()
  def get_server({__MODULE__, state}) do
    State.get_server(state)
  end

  @doc """
  Replaces the middlewares in the stack.
  """
  @spec set_middlewares(t(), [Middleware.t()]) :: t()
  def set_middlewares({__MODULE__, state}, middlewares) do
    {__MODULE__, State.set_middlewares(state, middlewares)}
  end

  @doc """
  Returns the server contained in the stack.
  """
  @spec get_middlewares(t()) :: [Middleware.t()]
  def get_middlewares({__MODULE__, state}) do
    State.get_middlewares(state)
  end

  ## Raxx.Server callbacks

  # NOTE those 4 can be rewritten using macros instead of apply for a minor performance increase
  @impl Server
  def handle_head(request, state) do
    handle_anything(request, state, :handle_head, :process_head)
  end

  @impl Server
  def handle_data(data, state) do
    handle_anything(data, state, :handle_data, :process_data)
  end

  @impl Server
  def handle_tail(tail, state) do
    handle_anything(tail, state, :handle_tail, :process_tail)
  end

  @impl Server
  def handle_info(message, state) do
    handle_anything(message, state, :handle_info, :process_info)
  end

  defp handle_anything(input, state, server_function, middleware_function) do
    case State.pop_middleware(state) do
      {nil, ^state} ->
        # time for the inner server to handle input
        server = State.get_server(state)
        {parts, new_server} = apply(Server, server_function, [server, input])

        state = State.set_server(state, new_server)
        {parts, state}

      {middleware, state} ->
        # the top middleware was popped off the stack
        {middleware_module, middleware_state} = middleware

        {parts, middleware_state, {__MODULE__, state}} =
          apply(middleware_module, middleware_function, [
            input,
            middleware_state,
            {__MODULE__, state}
          ])

        state = State.push_middleware(state, {middleware_module, middleware_state})
        {parts, state}
    end
  end
end
