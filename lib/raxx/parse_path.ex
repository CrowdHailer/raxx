defmodule Raxx.ParsePath do
  @moduledoc """
  Tokenize path elements. Replaces the raw path (`binary`) in `%Request.path` with `[binary]`

  To use this middleware just use it in any Raxx.Server module.

      use Raxx.ParsePath
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
        head = unquote(__MODULE__).split_path(head)
        super(head, config)
      end
    end
  end

  @doc """
  Splits path string into multiple segments.

  ## Examples
      iex> request(:GET, "/foo/bar/")
      ...> |> split_path()
      ...> |> Map.get(:path)
      ["foo", "bar"]
  """
  def split_path(%Raxx.Request{path: path} = head) when is_binary(path) do
    split_path = String.split(path, "/", trim: true)
    %{head | path: split_path}
  end

  def split_path(%Raxx.Request{path: nil} = head) do
    %{head | path: []}
  end

  def split_path(path) do
    path
  end
end
