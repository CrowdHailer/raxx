defmodule Raxx.RequestID do
  @moduledoc """

  """

  defmacro __using__(_options) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(__env) do
    quote do
      defoverridable Raxx.Server

      @impl Raxx.Server
      def handle_head(head, config) do
        {id, head} = unquote(__MODULE__).ensure_request_id(head)

        Logger.metadata(request_id: id)
        super(head, config)
      end
    end
  end

  def ensure_request_id(head) do
    case Raxx.get_header(head, "x-request-id") do
      nil ->
        id = UUID.uuid4()
        head = Raxx.set_header(head, "x-request-id", id)
        {id, head}

      id when byte_size(id) < 20 or byte_size(id) > 200 ->
        head =
          head
          |> Raxx.delete_header("x-request-id")
          |> Raxx.set_header("x-request-id", id)

        {id, head}

      id ->
        {id, head}
    end
  end
end
