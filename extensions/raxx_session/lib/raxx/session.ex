defmodule Raxx.Session do
  @moduledoc """

  A session is extracted from a request using `extract/2`.
  An updated session is sent the the client using `embed/3` or a response
  To expire a session use `expire/2` on a response.

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

  # get, extract that just expires error, not a deep API

  @doc """
  Extract a session from a request.

  Returns `{:ok, nil}` if session cookie is not set.
  When session cookie is set but cannot be decoded or is tampered with an error will be returned.
  """

  def extract(request, config = %__MODULE__{}) do
    extract(request, Raxx.get_header(request, "x-csrf-token"), config)
  end

  def extract(request, user_token, config = %__MODULE__{}) do
    case unprotected_extract(request, config) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, session} ->
        if __MODULE__.CSRFProtection.safe_request?(request) do
          {:ok, session}
        else
          __MODULE__.CSRFProtection.verify(session, user_token)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defdelegate get_csrf_token(session), to: __MODULE__.CSRFProtection

  # session works with any type
  @doc false
  def unprotected_extract(request, config = %__MODULE__{}) do
    case fetch_cookie(request, config.key) do
      # pass nil through, might want to set up an id
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
  def embed(response, session, config = %__MODULE__{}) do
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
  def expire(response, config = %__MODULE__{}) do
    # Needs to delete from store if we are doing that
    Raxx.set_header(response, "set-cookie", SetCookie.expire(config.key, config.cookie_options))
  end

  @doc """
  Add a message into a sessions flash.

  Any key can be used for the message, however `:info` and `:error` are common.
  """
  def put_flash(session, key, message) when is_atom(key) and is_binary(message) do
    session = session || %{}
    flash = Map.get(session, :_flash, %{})
    Map.put(session, :_flash, Map.put(flash, key, message))
  end

  @doc """
  Returns all the flash messages in a users session.

  This will be a map of `%{key => message}` set using `put_flash/3`.
  The returned session will have no flash messages.
  Remember this session must be embedded in the response otherwise flashes will be seen twice.
  """
  def pop_flash(session) do
    session = session || %{}
    Map.pop(session, :_flash, %{})
  end

  @doc """
  Extract and discard all flash messages in a users session.
  """
  def clear_flash(session) do
    {_flash, session} = pop_flash(session)
    session
  end
end
