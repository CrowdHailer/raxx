defmodule Raxx.RequestID do
  @moduledoc """
  Generate a unique identifier for a request.

  An invalid id, sent as `x-request-id`, will be overwritten if it is invalid.
  A valid id is any string between 20 and 200 charachters

  The request id is added to the Logger metadata as `:request_id`.
  To see the request id in your log output, configure your logger backends to include the `:request_id` metadata:

  To use this middleware just use it in any Raxx.Server module.

      use Raxx.RequestID
  """

  @header_name "x-request-id"

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

  @doc """
  Fetch the id of a request or generate new value

  ## Examples
      iex> request(:GET, "/")
      ...> |> set_header("x-request-id", "12345678901234567890")
      ...> |> ensure_request_id()
      ...> |> elem(0)
      "12345678901234567890"
  """
  def ensure_request_id(head) do
    case Raxx.get_header(head, @header_name) do
      nil ->
        id = UUID.uuid4()
        head = Raxx.set_header(head, @header_name, id)
        {id, head}

      invalid_id when byte_size(invalid_id) < 20 or byte_size(invalid_id) > 200 ->
        id = UUID.uuid4()

        head =
          head
          |> Raxx.delete_header(@header_name)
          |> Raxx.set_header(@header_name, id)

        {id, head}

      id ->
        {id, head}
    end
  end
end
