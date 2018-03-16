defmodule Raxx.BasicAuth do
  @moduledoc """
  Add protection to a Raxx application using Basic Authentication.

  Basic Authentication is specified in RFC 7617 (which obsoletes RFC 2617).

  ## Examples
  # Authenticate is Authenticated

  ## NOTE

  The Basic authentication scheme is not a secure method of user authentication
  https://tools.ietf.org/html/rfc7617#section-4


  """

  defmacro __using__(_opts) do
    quote do
      def authenticate(request) do
        case get_credential(request) do
          {user_id, password} ->
            verify_credentials(user_id, password)
          {:error, reason} ->
            {:error, reason}
        end
      end
# TODO define your own verify_credentials -> user
    end
  end

  @authentication_header "authorization"
  @default_realm "Site"
  @default_charset "UTF-8"

  def set_authentication(request, user_id, password) do
    request
    |> set_header(@authentication_header, authentication_header(user_id, password))
  end

  # TODO expose credentials function
  def authenticate(request) do
    # Raxx does not need to include OK
    # ~>> fetch_authentication_header
    case Raxx.get_header(request, @authentication_header) do
      nil ->
        {:error, :not_authorization_header}
      authorization ->
        case String.split(authorization, " ", parts: 2) do
          ["Basic", encoded] ->
            case Base.decode64(encoded) do
              {:ok, user_pass} ->
                case String.split(authorization, " ", parts: 2) do
                  [user_id, password] ->
                    :ok
                  _ ->
                    {:error, :invalid_user_pass}
                end
              :error ->
                {:error, :unable_to_decode_user_pass}
            end
          [unknown, _] ->
            {:error, :unknown_authentication_method}
          _ ->
            {:error, :invalid_authentication_header}
        end
    end
  end

  @doc """
  Generate a response to a request that failed to authenticate.

  ## Options

  - **realm:**
  """
  def unauthorized(options) do
    realm = Keyword.get(options, :realm, @default_realm)
    charset = Keyword.get(options, :charset, @default_charset)

    response(:unauthorized)
    |> set_header("www-authenticate", challenge_header(realm, charset))
    |> set_body("401 Unauthorized")
  end

  @doc """

  ## Examples

      iex> authentication_header("Aladdin", "open sesame")
      Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
  """
  def authentication_header(user_id, password) do
    "Basic " <> Base.encode64(user_pass(user_id, password))
  end

  @doc """
  Generate the challenge header sent by a server.

  This challenge is sent to a client in the `www-authenticate` header.
  Use this challenge to prompt a client into providing basic authentication credentials.

  ### Notes

  - The only valid charset is `UTF-8`; https://tools.ietf.org/html/rfc7617#section-2.1.
    A `nil` can be provided to this function to omit the parameter.

  - Validation should be added for the parameter values to ensure they only accept valid values.

  """
  def challenge_header(realm, nil) do
    "Basic realm=\"#{realm}\""
  end
  def challenge_header(realm, charset) do
    "Basic realm=\"#{realm}\", charset=\"#{charset}\""
  end

  # The user-id and password MUST NOT contain any control characters (see
  # "CTL" in Appendix B.1 of [RFC5234]).
  defp user_pass(user_id, password) do
    :ok = case :binary.match(user_id, [":"]) do
      {_, _} ->
        raise "a user-id containing a colon character is invalid"

      :nomatch ->
        :ok
    end

    user_id <> ":" <> password
  end
end
