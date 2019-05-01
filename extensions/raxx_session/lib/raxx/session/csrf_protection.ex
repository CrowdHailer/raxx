defmodule Raxx.Session.CSRFProtection do
  @unprotected_methods [:HEAD, :GET, :OPTIONS]
  @token_size 16
  @encoded_token_size 24
  @double_encoded_token_size 32

  def safe_request?(%{method: method}) when method in @unprotected_methods, do: true
  def safe_request?(_), do: false

  def verify(_, nil), do: {:error, :csrf_missing}

  def verify(session, user_token) when is_binary(user_token) do
    if valid_csrf_token?(session_token(session), user_token) do
      {:ok, session}
    end
  end

  def get_csrf_token(session = %{}) do
    case session_token(session) do
      # If not the right size then _csrf_token field has been modified
      csrf_token when is_binary(csrf_token) and byte_size(csrf_token) == @encoded_token_size ->
        user_token = mask(csrf_token)
        {user_token, session}

      nil ->
        csrf_token = generate_token()
        session = Map.put(session, :_csrf_token, csrf_token)
        user_token = mask(csrf_token)
        {user_token, session}
    end
  end

  defp session_token(nil), do: nil
  defp session_token(session = %{}), do: Map.get(session, :_csrf_token)

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
