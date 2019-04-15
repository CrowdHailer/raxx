defmodule Raxx.Session.SignedCookie do
  @enforce_keys [:secret_key_base, :salt]
  defstruct @enforce_keys

  def config(options) do
    # TODO check secret key base length
    secret_key_base = Keyword.fetch!(options, :secret_key_base)
    salt = Keyword.fetch!(options, :salt)

    %__MODULE__{secret_key_base: secret_key_base, salt: salt}
  end

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
