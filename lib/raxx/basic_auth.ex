defmodule Raxx.BasicAuth do
  @moduledoc """
  Add protection to a Raxx application using Basic Authentication.

  *Basic Authentication is specified in RFC 7617 (which obsoletes RFC 2617).*

  This module provides helpers for submitting and verifying credentials.

  ### Submitting credentials

  A client (or test case) can add user credentials to a request with `set_credentials/3`

      iex> request(:GET, "/")
      ...> |> set_credentials("Aladdin", "open sesame")
      ...> |> get_header("authorization")
      "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ=="

  ### Verifying fixed credentials

  A server can authenticate a request against a fixed set of credentials using `authenticate/3`

      iex> request(:GET, "/")
      ...> |> set_header("authorization", "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==")
      ...> |> authenticate("Aladdin", "open sesame")
      {:ok, "Aladdin"}

      iex> request(:GET, "/")
      ...> |> set_header("authorization", "Basic SmFmYXI6bXkgbGFtcA==")
      ...> |> authenticate("Aladdin", "open sesame")
      {:error, :invalid_credentials}

  ### Verifying multiple credentials

  To authenticate a request when credentials are not fixed, define an application authenticate function.
  This function can authenticate a user in any way it wants. e.g. by fetching the user from the database.
  Extracting credentials from a received request can be done using `get_credentials/1`.

      defmodule MyApp.Admin do
        def authenticate(request) do
          with {:ok, {user_id, password}} <- get_credentials(request) do
            # Find user and verify credentials
            {:ok, user}
          end
        end
      end


  NOTE: when comparing saved passwords with submitted passwords use `secure_compare/2` to protect against timing attacks.

  ### Challenging unauthorized requests

  If a request is submitted with absent or invalid credentials a server should inform the client that it is accessing a resource protected with basic authentication.
  Use `unauthorized/1` to create such a response.

  ## NOTE

  - The Basic authentication scheme is not a secure method of user authentication
  https://tools.ietf.org/html/rfc7617#section-4

  - This module will be extracted to a separate project before the release of raxx 1.0
  """

  import Raxx

  @authentication_header "authorization"
  @default_realm "Site"
  @default_charset "UTF-8"

  @doc """
  Add a users credentials to a request to authenticate it.

  NOTE:
  1. The user-id and password MUST NOT contain any control characters
  2. The user-id must not contain a `:`

  """
  def set_credentials(request, user_id, password) do
    request
    |> set_header(@authentication_header, authentication_header(user_id, password))
  end

  @doc """
  Extract credentials submitted using the Basic authentication scheme.

  If credentials we not provided or are malformed an error is returned
  """
  def get_credentials(request) do
    case get_header(request, @authentication_header) do
      nil ->
        {:error, :not_authorization_header}

      authorization ->
        case String.split(authorization, " ", parts: 2) do
          ["Basic", encoded] ->
            case Base.decode64(encoded) do
              {:ok, user_pass} ->
                case String.split(user_pass, ":", parts: 2) do
                  [user_id, password] ->
                    secure_compare(user_id, password)
                    {:ok, {user_id, password}}

                  _ ->
                    {:error, :invalid_user_pass}
                end

              :error ->
                {:error, :unable_to_decode_user_pass}
            end

          [_unknown, _] ->
            {:error, :unknown_authentication_method}

          _ ->
            {:error, :invalid_authentication_header}
        end
    end
  end

  @doc """
  Authenticate a request against fixed credentials.
  """
  def authenticate(request, access_user_id, access_password) do
    with {:ok, {user_id, password}} <- get_credentials(request) do
      if secure_compare(user_id, access_user_id) && secure_compare(password, access_password) do
        {:ok, access_user_id}
      else
        {:error, :invalid_credentials}
      end
    end
  end

  @doc """
  Generate a response to a request that failed to authenticate.

  The response will contain a challenge for the client in the `www-authenticate` header.
  Use an unauthorized response to prompt a client into providing basic authentication credentials.

  ## Options

  - **realm:** describe the protected area. default `"Site"`
  - **charset:** default `"UTF-8"`

  ### Notes

  - The only valid charset is `UTF-8`; https://tools.ietf.org/html/rfc7617#section-2.1.
    A `nil` can be provided to this function to omit the parameter.

  - Validation should be added for the parameter values to ensure they only accept valid values.
  """
  def unauthorized(options) do
    realm = Keyword.get(options, :realm, @default_realm)
    charset = Keyword.get(options, :charset, @default_charset)

    response(:unauthorized)
    |> set_header("www-authenticate", challenge_header(realm, charset))
    |> set_body("401 Unauthorized")
  end

  defp authentication_header(user_id, password) do
    "Basic " <> Base.encode64(user_pass(user_id, password))
  end

  defp challenge_header(realm, nil) do
    "Basic realm=\"#{realm}\""
  end

  defp challenge_header(realm, charset) do
    "Basic realm=\"#{realm}\", charset=\"#{charset}\""
  end

  defp user_pass(user_id, password) do
    :ok =
      case :binary.match(user_id, [":"]) do
        {_, _} ->
          raise "a user-id containing a colon character is invalid"

        :nomatch ->
          :ok
      end

    user_id <> ":" <> password
  end

  @doc """
  Compares the two binaries in constant-time to avoid timing attacks.
  See: http://codahale.com/a-lesson-in-timing-attacks/
  """
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
