defmodule Raxx.Session.EncryptedCookie do
  @moduledoc """
  Store the session in an encrypted cookie.

  This module is not normally used directly.
  Instead see `Raxx.Session` and use this module as the `:store` option.

  ## Options

  - `:secret_key_base` - used to generate the signing key
  - `:signing_salt` - a salt used with `secret_key_base` to generate a signing_secret.
  - `:encryption_salt` - a salt used with `secret_key_base` to generate a encryption_secret.
  """

  @enforce_keys [:secret_key_base, :encryption_salt, :signing_salt]
  defstruct @enforce_keys

  def config(options) do
    {secret_key_base, options} = Keyword.pop(options, :secret_key_base)

    secret_key_base ||
      raise ArgumentError, "#{__MODULE__} requires the :secret_key_base option to be set"

    validate_secret_key_base(secret_key_base)

    {signing_salt, _options} = Keyword.pop(options, :signing_salt)

    signing_salt ||
      raise ArgumentError, "#{__MODULE__} requires the :signing_salt option to be set"

    {encryption_salt, _options} = Keyword.pop(options, :encryption_salt)

    encryption_salt ||
      raise ArgumentError, "#{__MODULE__} requires the :encryption_salt option to be set"

    %__MODULE__{
      secret_key_base: secret_key_base,
      signing_salt: signing_salt,
      encryption_salt: encryption_salt
    }
  end

  defp validate_secret_key_base(secret_key_base) when byte_size(secret_key_base) < 64 do
    raise(ArgumentError, "#{__MODULE__} requires `secret_key_base` to be at least 64 bytes")
  end

  defp validate_secret_key_base(secret_key_base), do: secret_key_base

  def fetch(session_string, config = %__MODULE__{}) do
    case Plug.Crypto.MessageEncryptor.decrypt(
           session_string,
           encryption_secret(config),
           signing_secret(config)
         ) do
      {:ok, binary} ->
        {:ok, Plug.Crypto.safe_binary_to_term(binary)}

      :error ->
        {:error, :invalid_signature}
    end
  end

  def put(session, config) do
    binary = :erlang.term_to_binary(session)

    Plug.Crypto.MessageEncryptor.encrypt(
      binary,
      encryption_secret(config),
      signing_secret(config)
    )
  end

  defp signing_secret(%__MODULE__{secret_key_base: secret_key_base, signing_salt: signing_salt}) do
    Plug.Crypto.KeyGenerator.generate(secret_key_base, signing_salt)
  end

  defp encryption_secret(%__MODULE__{
         secret_key_base: secret_key_base,
         encryption_salt: encryption_salt
       }) do
    Plug.Crypto.KeyGenerator.generate(secret_key_base, encryption_salt)
  end
end
