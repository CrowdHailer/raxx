defmodule Raxx.Session.SignedCookie do
  @moduledoc """
  Stores the session in a signed cookie.

  **Note: the contents of the cookie can be viewed by the client,
  an encrypted cookie store must be used to hide data from client.**

  This module is not normally used directly.
  Instead see `Raxx.Session` and use this module as the `:store` option.

  ## Options

    - `:secret_key_base` - used to generate the signing key
    - `:salt` - a salt used with `secret_key_base` to generate a key for signing/verifying a cookie.

  TODO support key generation options, currently sensible defaults are used.
  """
  @enforce_keys [:secret_key_base, :salt]
  defstruct @enforce_keys

  def config(options) do
    {secret_key_base, options} = Keyword.pop(options, :secret_key_base)

    secret_key_base ||
      raise ArgumentError, "#{__MODULE__} requires the :secret_key_base option to be set"

    {salt, options} = Keyword.pop(options, :salt)
    salt || raise ArgumentError, "#{__MODULE__} requires the :salt option to be set"

    %__MODULE__{secret_key_base: secret_key_base, salt: salt}
  end

  defp validate_secret_key_base(secret_key_base) when byte_size(secret_key_base) < 64 do
    raise(ArgumentError, "#{__MODULE__} requires `secret_key_base` to be at least 64 bytes")
  end

  defp validate_secret_key_base(secret_key_base), do: secret_key_base

  def fetch(session_string, config = %__MODULE__{}) do
    case Plug.Crypto.MessageVerifier.verify(session_string, key(config)) do
      {:ok, binary} ->
        {:ok, Plug.Crypto.safe_binary_to_term(binary)}

      :error ->
        {:error, :invalid_signature}
    end
  end

  def put(session, config) do
    binary = :erlang.term_to_binary(session)
    Plug.Crypto.MessageVerifier.sign(binary, key(config))
  end

  defp key(%__MODULE__{secret_key_base: secret_key_base, salt: salt}) do
    Plug.Crypto.KeyGenerator.generate(secret_key_base, salt)
  end
end
