defmodule Raxx.Session do
  @moduledoc """
  Example fetch the session update it put it

  options :key
  options :store
  options :cookie options

  ## Examples

      # iex> Raxx.request(:GET, "/")
      # ...> RaxxSession.
  """

  @enforce_keys [:key, :store, :cookie_options]
  defstruct @enforce_keys

  def config(options) do
    {key, options} = Keyword.pop(options, :key)
    key || raise ArgumentError, "#{__MODULE__} requires the :key option to be set"
    {store, options} = Keyword.pop(options, :store)
    store || raise ArgumentError, "#{__MODULE__} requires the :store option to be set"
    # TODO take cookie options
    cookie_options = []
    store = store.config(options)

    %__MODULE__{key: key, store: store, cookie_options: cookie_options}
  end

  def fetch(request, config = %__MODULE__{}) do
    case fetch_cookie(request, config.key) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, cookie} ->
        fetch_session(cookie, config.store)
    end
  end

  # get just drops error, not a deep API

  defp fetch_cookie(%{headers: headers}, key) do
    headers = :proplists.get_all_values("cookie", headers)

    cookies = for header <- headers, kv <- Cookie.parse(header), into: %{}, do: kv
    {:ok, Map.get(cookies, key)}
  end

  defp fetch_session(cookie, store = %store_mod{}) do
    store_mod.fetch(cookie, store)
  end

  # set update override
  # optional previous option
  def put(response, session, config = %__MODULE__{}) do
    store = %store_mod{} = config.store
    session_string = store_mod.put(session, store)

    Raxx.set_header(
      response,
      "set-cookie",
      SetCookie.serialize(config.key, session_string, config.cookie_options)
    )
  end

  def drop(response, config = %__MODULE__{}) do
    # Needs to delete from store if we are doing that
    Raxx.set_header(response, "set-cookie", SetCookie.expire(config.key))
  end
end
