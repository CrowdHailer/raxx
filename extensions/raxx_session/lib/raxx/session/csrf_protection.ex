defmodule Raxx.Session.CSRFProtection do
  @unprotected_methods [:HEAD, :GET, :OPTIONS]
  @token_size 16
  @encoded_token_size 24
  @double_encoded_token_size 32
  #   # TODO configure key
  #   # TODO error for not a map
  # Move because it's not part of protection??
  def safe_request?(%{method: method}) when method in @unprotected_methods, do: true
  def safe_request?(_), do: false

  def verify(%{}, nil), do: {:error, :csrf_missing}

  def verify(session = %{}, user_token) when is_binary(user_token) do
    if valid_csrf_token?(session._csrf_token, user_token) do
      {:ok, session}
    end
  end

  def get_csrf_token(session = %{}) do
    case Map.fetch(session, :_csrf_token) do
      {:ok, key} ->
        # TODO check key, raise error
        {key, session}

      :error ->
        csrf_token = generate_token()
        session = Map.put(session, :_csrf_token, csrf_token)
        user_token = mask(csrf_token)
        {user_token, session}
    end
  end

  defp valid_csrf_token?(
         <<csrf_token::@encoded_token_size-binary>>,
         <<user_token::@double_encoded_token_size-binary, mask::@encoded_token_size-binary>>
       ) do
    case Base.decode64(user_token) do
      {:ok, user_token} -> Plug.Crypto.masked_compare(csrf_token, user_token, mask)
      :error -> false
    end
  end

  defp mask(token) do
    mask = generate_token()
    Base.encode64(Plug.Crypto.mask(token, mask)) <> mask
  end

  defp generate_token do
    Base.encode64(:crypto.strong_rand_bytes(@token_size))
  end
end

#
# # If you want to check session in handle head and csrf is in body use unprotected and know what your doing
# # plug doesn't let you do this because protect middleware will wait for body
