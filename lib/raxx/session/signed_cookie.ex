defmodule Raxx.Session.SignedCookie do
  # pack unpack if putting in other headers
  @moduledoc """
  Use cookies to add a persistant session for a client.

  Sessions stored this way are signed to ensure that they have not been tampered.
  The secret given to config must be kept secure to prevent sessions being tampered

  **NOTE:** the session is not encrypted so a user can read any value from the session, they are just unable to modify it.

  ### Writing a session

  Any term can be embedded in a response as the clients session.

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.response(:no_content)
      ...> |> SignedCookie.embed({:user, 25}, config)
      ...> |> Raxx.get_header("set-cookie")
      "raxx.session=g2gCZAAEdXNlcmEZ--gpW5K8Pgle9isXR5Qymz4m2VEU1DuEosNfgpLTQuRn0=; path=/; HttpOnly"

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.request(:GET, "/")
      ...> |> Raxx.set_header("cookie", "raxx.session=g2gCZAAEdXNlcmEZ--gpW5K8Pgle9isXR5Qymz4m2VEU1DuEosNfgpLTQuRn0=")
      ...> |> SignedCookie.extract(config)
      {:ok, {:user, 25}}

      iex> config = SignedCookie.config(secret: "eggplant")
      ...> Raxx.response(:no_content)
      ...> |> SignedCookie.expire(config)
      ...> |> Raxx.get_header("set-cookie")
      "raxx.session=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; max-age=0; HttpOnly"

  ## NOTE

  - This module will be extracted from the Raxx project before 1.0 release.

  """

  @default_cookie_name "raxx.session"

  @enforce_keys [:secret, :name, :past_keys]
  defstruct @enforce_keys

  def config(opts) do
    secret =
      case Keyword.fetch(opts, :secret) do
        {:ok, secret} ->
          secret

        :error ->
          raise "A `:secret` must be set when using signed cookies."
      end

    %__MODULE__{
      secret: secret,
      name: @default_cookie_name,
      past_keys: []
    }
  end

  def embed(response, session, config = %__MODULE__{}) do
    payload = safe_encode(session)
    digest = safe_digest(payload, config)

    # Where to put 4096 check
    # It could like in Raxx.set_cookie
    response
    |> Raxx.set_header(
      "set-cookie",
      SetCookie.serialize(config.name, payload <> "--" <> digest)
    )
  end

  def extract(request, config = %__MODULE__{}) do
    case Raxx.get_header(request, "cookie") do
      nil ->
        :eror

      session_cookie ->
        {:ok, session_cookie} =
          Cookie.parse(session_cookie)
          |> Map.fetch("#{config.name}")

        case String.split(session_cookie, "--", parts: 2) do
          [payload, digest] ->
            # TODO need to do old secrets
            if secure_compare(digest, safe_digest(payload, config)) do
              safe_decode(payload)
            else
            end
        end
    end
  end

  def expire(response, config = %__MODULE__{}) do
    response
    |> Raxx.set_header("set-cookie", SetCookie.expire(config.name))
  end

  defp safe_digest(payload, config) do
    :crypto.hmac(:sha256, config.secret, payload)
    |> Base.url_encode64()
  end

  defp safe_encode(term) do
    {:ok, encoded_session} = encode(term)
    Base.url_encode64(encoded_session)
  end

  def encode(term) do
    {:ok, :erlang.term_to_binary(term)}
  end

  def safe_decode(binary) do
    {:ok, encoded} = Base.url_decode64(binary)
    decode(encoded)
  end

  # NOTE make sure decode is only called after verifying digest
  # https://elixirforum.com/t/static-and-session-security-fixes-for-plug/3913
  def decode(binary) do
    try do
      term = :erlang.binary_to_term(binary)
      {:ok, term}
    rescue
      _e in ArgumentError ->
        {:error, :unable_to_decode_session}
    end
  end

  def secure_compare(left, right) do
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
