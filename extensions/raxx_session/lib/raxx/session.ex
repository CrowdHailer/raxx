defmodule Raxx.Session do
  @moduledoc """
  Working with sessions in Raxx applications.

  A session is extracted from a request using `fetch/2`.
  They can be updated or dropped by using `put/3` or `drop/2` on a response.

  ## Configuration

  All session functions take a configuration as a parameter.
  To check configuration only one it is best to configure a session, and it's store, at startup.

  When using the `SignedCookie` store then sessions are compatible with sessions from plug applications.

  ## Options

    - `:store` - session store module (required)
    - `:key` - session cookie key (required)

  ### Cookie options

  Any option that can be passed as an option to `SetCookie.serialize/3` can be set as a session option.
  `:domain`, `:max_age`, `:path`, `:http_only`, `:secure`, `:extra`

  ### Store options

  Additional options may be required dependant on the store module being used.
  For example `SignedCookie` requires `secret_key_base` and `salt`.
  """

  @enforce_keys [:key, :store, :cookie_options]
  defstruct @enforce_keys

  @cookie_options [:domain, :max_age, :path, :secure, :http_only, :extra]

  @doc """
  Set up and check session configuration.

  See [options](#module-options) for details.
  """
  def config(options) do
    {key, options} = Keyword.pop(options, :key)
    key || raise ArgumentError, "#{__MODULE__} requires the :key option to be set"
    {store, options} = Keyword.pop(options, :store)
    store || raise ArgumentError, "#{__MODULE__} requires the :store option to be set"

    cookie_options = Keyword.take(options, @cookie_options)
    store = store.config(options)

    %__MODULE__{key: key, store: store, cookie_options: cookie_options}
  end

  # get, fetch that just drops error, not a deep API
  @doc """
  Fetch a session from a request.

  Returns `{:ok, nil}` if session cookie is not set.
  When session cookie is set but cannot be decoded or is tampered with an error will be returned.
  """
  def fetch(request, config = %__MODULE__{}) do
    case fetch_cookie(request, config.key) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, cookie} ->
        fetch_session(cookie, config.store)
    end
  end

  defp fetch_cookie(%{headers: headers}, key) do
    headers = :proplists.get_all_values("cookie", headers)

    cookies = for header <- headers, kv <- Cookie.parse(header), into: %{}, do: kv
    {:ok, Map.get(cookies, key)}
  end

  defp fetch_session(cookie, store = %store_mod{}) do
    store_mod.fetch(cookie, store)
  end

  # set update override
  # optional previous last argument to see if changed.
  @doc """
  Overwrite a users session to a new value.

  The whole session object must be passed to this function.
  """
  def put(response, session, config = %__MODULE__{}) do
    store = %store_mod{} = config.store
    session_string = store_mod.put(session, store)

    Raxx.set_header(
      response,
      "set-cookie",
      SetCookie.serialize(config.key, session_string, config.cookie_options)
    )
  end

  @doc """
  Instruct a client to end a session.
  """
  def drop(response, config = %__MODULE__{}) do
    # Needs to delete from store if we are doing that
    Raxx.set_header(response, "set-cookie", SetCookie.expire(config.key, config.cookie_options))
  end
end
