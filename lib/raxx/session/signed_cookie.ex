defmodule Raxx.Session.SignedCookie do
  @moduledoc """
  Use signed cookies to store the session for a client.

  Sessions stored this way are signed to ensure that they have not been tampered.
  The secret given to config must be kept secure to prevent sessions being tampered

  **NOTE:** the session is not encrypted so a user can read any value from the session, they are just unable to modify it.

  ### Configuring sessions

  Configuration is required to use signed cookies a session store.
  The most important value is the secret that is used when signing and verifying.
  To set up an new configuration use `config/1`.

  It often makes sense to keep your session config in the application state

      def handle_request(request, %{sessions: session_config})

  ### Working with sessions

  A session can be any term.
  Use `embed/3` to set a new session value for a client.
  Embedding a new session value will override any previouse value.

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.response(:no_content)
      ...> |> SignedCookie.embed({:user, 25}, config)
      ...> |> Raxx.get_header("set-cookie")
      "raxx.session=g2gCZAAEdXNlcmEZ--gpW5K8Pgle9isXR5Qymz4m2VEU1DuEosNfgpLTQuRn0=; path=/; HttpOnly"

  A client that has received a session should send it with all subequent requests.
  A session can be retrieved using `extract/2`.
  This step will also verify that the session has not been tampered with.

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.request(:GET, "/")
      ...> |> Raxx.set_header("cookie", "raxx.session=g2gCZAAEdXNlcmEZ--gpW5K8Pgle9isXR5Qymz4m2VEU1DuEosNfgpLTQuRn0=")
      ...> |> SignedCookie.extract(config)
      {:ok, {:user, 25}}

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.request(:GET, "/")
      ...> |> Raxx.set_header("cookie", "raxx.session=g2gCZAAEdXNlcmEZ--sfbxaB-IEgUt_NwdmmZpJny9OzOx15D-6uwusW6X1ZY=")
      ...> |> SignedCookie.extract(config)
      {:error, :could_not_verify_signature}

  A session can be concluded by marking as expired.
  For example in response to a users sign out request.

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.response(:no_content)
      ...> |> SignedCookie.expire(config)
      ...> |> Raxx.get_header("set-cookie")
      "raxx.session=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; max-age=0; HttpOnly"

  ## NOTE

  - This module will be extracted from the Raxx project before 1.0 release.
  - The Rack.Session.Cookie module was the inspiration for this functionality.
    https://github.com/rack/rack/blob/master/lib/rack/session/cookie.rb
  """

  @default_cookie_name "raxx.session"

  @enforce_keys [:secret, :cookie_name, :previous_secrets]
  defstruct @enforce_keys

  @doc """
  Setup configuration to work with sessions

  ## Options

  - **secret:** (required) a secure random value used for signing session data.
  - **cookie_name:** default is `"raxx.session"`
  - **previous_secrets:** acceptable secrets to verify against old sessions.
  """
  def config(options) do
    secret =
      case Keyword.fetch(options, :secret) do
        {:ok, secret} ->
          secret

        :error ->
          raise "A `:secret` must be set when using signed cookies."
      end

    cookie_name = Keyword.get(options, :cookie_name, @default_cookie_name)
    previous_secrets = Keyword.get(options, :previous_secrets, [])

    %__MODULE__{
      secret: secret,
      cookie_name: cookie_name,
      previous_secrets: previous_secrets
    }
  end

  @doc """
  Overwrite a clients session with a new value.
  """
  def embed(response, session, session_config = %__MODULE__{}) do
    payload = safe_encode(session)
    digest = safe_digest(payload, session_config.secret)

    # Where to put 4096 check
    # It could be in Raxx.set_cookie
    response
    |> Raxx.set_header(
      "set-cookie",
      SetCookie.serialize(session_config.cookie_name, payload <> "--" <> digest)
    )
  end

  @doc """
  Extract and verify the session sent from a client.
  """
  def extract(request, session_config = %__MODULE__{}) do
    case Raxx.get_header(request, "cookie") do
      nil ->
        {:error, :no_cookies_sent}

      cookie_header ->
        case Cookie.parse(cookie_header) do
          cookies = %{} ->
            case Map.fetch(cookies, "#{session_config.cookie_name}") do
              {:ok, session_cookie} ->
                case String.split(session_cookie, "--", parts: 2) do
                  [payload, digest] ->
                    if verify_signature(payload, digest, [session_config.secret | session_config.previous_secrets]) do
                      safe_decode(payload)
                    else
                      {:error, :could_not_verify_signature}
                    end
                  _ ->
                    {:error, :invalid_session_cookie}
                end
              :error ->
                {:error, :no_session_cookie}
            end
        end
    end
  end

  @doc """
  Sent a response to client informing it to clear a session.
  """
  def expire(response, session_config = %__MODULE__{}) do
    response
    |> Raxx.set_header("set-cookie", SetCookie.expire(session_config.cookie_name))
  end

  defp safe_digest(payload, secret) do
    :crypto.hmac(:sha256, secret, payload)
    |> Base.url_encode64()
  end

  defp safe_encode(term) do
    {:ok, encoded_session} = encode(term)
    Base.url_encode64(encoded_session)
  end

  defp encode(term) do
    {:ok, :erlang.term_to_binary(term)}
  end

  defp safe_decode(binary) do
    {:ok, encoded} = Base.url_decode64(binary)
    decode(encoded)
  end

  # NOTE make sure decode is only called after verifying digest
  # https://elixirforum.com/t/static-and-session-security-fixes-for-plug/3913
  defp decode(binary) do
    try do
      term = :erlang.binary_to_term(binary)
      {:ok, term}
    rescue
      _e in ArgumentError ->
        {:error, :unable_to_decode_session}
    end
  end

  defp verify_signature(payload, digest, secrets) do
    Enum.any?(secrets, fn(secret) ->
      secure_compare(digest, safe_digest(payload, secret))
    end)
  end

  defp secure_compare(left, right) do
    if byte_size(left) == byte_size(right) do
      secure_compare(left, right, 0) == 0
    else
      false
    end
  end

  defp secure_compare(<<x, left::binary>>, <<y, right::binary>>, acc) do
    import Bitwise
    xorred = x ^^^ y
    secure_compare(left, right, acc ||| xorred)
  end

  defp secure_compare(<<>>, <<>>, acc) do
    acc
  end
end
