defmodule Raxx.Session.PlugCompatibilityTest do
  use ExUnit.Case, async: true

  defmodule RaxxSessionApp do
    use Raxx.SimpleServer
    alias Raxx.Session

    def handle_request(request = %{path: ["set", value]}, state) do
      {:ok, session} = Session.extract(request, state.session_config)
      session = session || %{}

      previous = Map.get(session, :value, "")
      session = Map.put(session, :value, value)

      response(:ok)
      |> Session.embed(session, state.session_config)
      |> set_body(previous)
    end
  end

  defmodule PlugSessionApp do
    alias Plug.Conn
    alias Plug.Session

    def call(conn, config) do
      conn
      |> set_secret(config.secret_key_base)
      |> Session.call(config.session_config)
      |> endpoint(nil)
    end

    def set_secret(conn, secret_key_base) do
      %{conn | secret_key_base: secret_key_base}
    end

    def endpoint(conn = %{path_info: ["set", value]}, _) do
      conn =
        conn
        |> Conn.fetch_session()

      # NOTE get session transparently casts keys to strings
      previous = patched_get_session(conn, :value) || ""

      conn
      |> Conn.put_session(:value, value)
      |> Conn.send_resp(200, previous)
    end

    defp patched_get_session(conn, key) do
      conn
      |> Conn.get_session()
      |> Map.get(key)
    end
  end

  test "Signed Sessions are interchangeable" do
    key = "my_shared_session"
    signing_salt = "sea"

    secret_key_base = random_string(64)

    plug_session_config = Plug.Session.init(store: :cookie, key: key, signing_salt: signing_salt)

    plug_config = %{secret_key_base: secret_key_base, session_config: plug_session_config}

    raxx_session_config =
      Raxx.Session.config(
        store: Raxx.Session.SignedCookie,
        secret_key_base: secret_key_base,
        key: key,
        salt: signing_salt
      )

    raxx_config = %{session_config: raxx_session_config}
    do_test(plug_config, raxx_config)
  end

  test "Encrypted Sessions are interchangeable" do
    key = "my_shared_session"
    signing_salt = "sea"
    encryption_salt = "rock"

    secret_key_base = random_string(64)

    plug_session_config =
      Plug.Session.init(
        store: :cookie,
        key: key,
        encryption_salt: encryption_salt,
        signing_salt: signing_salt
      )

    plug_config = %{secret_key_base: secret_key_base, session_config: plug_session_config}

    raxx_session_config =
      Raxx.Session.config(
        store: Raxx.Session.EncryptedCookie,
        secret_key_base: secret_key_base,
        key: key,
        encryption_salt: encryption_salt,
        signing_salt: signing_salt
      )

    raxx_config = %{session_config: raxx_session_config}
    do_test(plug_config, raxx_config)
  end

  def do_test(plug_config, raxx_config) do
    first = random_string(10)
    second = random_string(10)

    first_conn =
      Plug.Test.conn(:get, "/set/#{first}")
      |> PlugSessionApp.call(plug_config)

    [first_set_cookie_string] = Plug.Conn.get_resp_header(first_conn, "set-cookie")
    first_set_cookie = SetCookie.parse(first_set_cookie_string)
    first_cookie_string = Cookie.serialize({first_set_cookie.key, first_set_cookie.value})

    request =
      Raxx.request(:GET, "/set/#{second}")
      |> Raxx.set_header("cookie", first_cookie_string)

    response = RaxxSessionApp.handle_request(request, raxx_config)
    assert first = response.body

    second_set_cookie_string = Raxx.get_header(response, "set-cookie")
    second_set_cookie = SetCookie.parse(second_set_cookie_string)
    second_cookie_string = Cookie.serialize({second_set_cookie.key, second_set_cookie.value})

    second_conn =
      Plug.Test.conn(:get, "/set/end")
      |> Plug.Conn.put_req_header("cookie", second_cookie_string)
      |> PlugSessionApp.call(plug_config)

    assert second_conn.resp_body == second
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end
end
