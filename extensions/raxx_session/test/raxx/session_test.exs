defmodule Raxx.SessionTest do
  use ExUnit.Case, async: true
  doctest Raxx.Session

  describe "configuration" do
    test "configuration requires a key" do
      assert_raise(ArgumentError, ~r/:key/, fn ->
        Raxx.Session.config(store: Raxx.Session.SignedCookie)
      end)
    end

    test "configuration requires a store" do
      assert_raise(ArgumentError, ~r/:store/, fn ->
        Raxx.Session.config(key: "my_app_session")
      end)
    end

    test "valid store configuration is required" do
      assert_raise(ArgumentError, ~r/:secret_key_base/, fn ->
        Raxx.Session.config(
          key: "my_app_session",
          store: Raxx.Session.SignedCookie,
          salt: "smelling"
        )
      end)
    end
  end

  describe "default configuration" do
    setup %{} do
      config =
        Raxx.Session.config(
          key: "my_app_session",
          store: Raxx.Session.SignedCookie,
          secret_key_base: String.duplicate("squirrel", 8),
          salt: "epsom"
        )

      {:ok, config: config}
    end

    test "can extract an unprotected session from safe request", %{config: config} do
      session = %{"user" => "friend"}

      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      session_cookie = cookie.value

      assert map_size(cookie.attributes) == 2
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true

      request =
        Raxx.request(:GET, "/")
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:ok, ^session} = Raxx.Session.extract(request, config)
    end

    test "can extract a protected session from unsafe request", %{config: config} do
      session = %{"user" => "friend"}
      {token, session} = Raxx.Session.get_csrf_token(session)

      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      session_cookie = cookie.value

      assert map_size(cookie.attributes) == 2
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true

      request =
        Raxx.request(:POST, "/")
        |> Raxx.set_header("x-csrf-token", token)
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:ok, ^session} = Raxx.Session.extract(request, config)
    end

    test "cant extract an unprotected session from unsafe request", %{config: config} do
      session = %{"user" => "friend"}

      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      session_cookie = cookie.value

      assert map_size(cookie.attributes) == 2
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true

      request =
        Raxx.request(:POST, "/")
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:error, :csrf_missing} = Raxx.Session.extract(request, config)
    end

    test "can't extract session with invalid csrf token", %{config: config} do
      session = %{"user" => "friend"}
      {_token, session} = Raxx.Session.get_csrf_token(session)

      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      session_cookie = cookie.value

      assert map_size(cookie.attributes) == 2
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true

      request =
        Raxx.request(:POST, "/")
        |> Raxx.set_header("x-csrf-token", "too-short")
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:error, :invalid_csrf_token} = Raxx.Session.extract(request, config)
    end

    test "can't extract session with incorrect csrf token", %{config: config} do
      session = %{"user" => "friend"}
      {_token, session} = Raxx.Session.get_csrf_token(session)

      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      session_cookie = cookie.value

      assert map_size(cookie.attributes) == 2
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true

      {incorrect_token, _other_session} = Raxx.Session.get_csrf_token(%{})

      request =
        Raxx.request(:POST, "/")
        |> Raxx.set_header("x-csrf-token", incorrect_token)
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:error, :csrf_check_failed} = Raxx.Session.extract(request, config)
    end

    test "can't extract session with incorrect csrf checkin in session", %{config: config} do
      session = %{"user" => "friend"}
      {token, _session} = Raxx.Session.get_csrf_token(session)

      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      session_cookie = cookie.value

      assert map_size(cookie.attributes) == 2
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true

      request =
        Raxx.request(:POST, "/")
        |> Raxx.set_header("x-csrf-token", token)
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:error, :csrf_check_missing} = Raxx.Session.extract(request, config)
    end

    test "protection is not checked when there is no session", %{config: config} do
      request = Raxx.request(:POST, "/")
      assert {:ok, nil} = Raxx.Session.extract(request, config)
    end

    test "can expire a session", %{config: config} do
      response =
        Raxx.response(:ok)
        |> Raxx.Session.expire(config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      assert "" = cookie.value

      assert map_size(cookie.attributes) == 4
      assert cookie.attributes.path == "/"
      assert cookie.attributes.http_only == true
      assert cookie.attributes.expires == "Thu, 01 Jan 1970 00:00:00 GMT"
      assert cookie.attributes.max_age == "0"
    end

    test "request without cookies returns no session", %{config: config} do
      request = Raxx.request(:GET, "/")
      assert {:ok, nil} = Raxx.Session.extract(request, config)
    end

    test "request with other cookies returns no session", %{config: config} do
      request =
        Raxx.request(:GET, "/")
        |> Map.put(:headers, [{"cookie", "foo=1"}, {"cookie", "bar=2; baz=3"}])

      assert {:ok, nil} = Raxx.Session.extract(request, config)
    end

    test "tampered with cookie, different key is an error", %{config: config} do
      session = %{"user" => "foe"}
      store_config = %store_mod{} = config.store
      session_cookie = store_mod.put(session, %{store_config | secret_key_base: "!!TAMPERED!!"})

      request =
        Raxx.request(:GET, "/")
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:error, _} = Raxx.Session.extract(request, config)
    end
  end

  describe "set cookie options" do
    setup %{} do
      config =
        Raxx.Session.config(
          key: "my_app_session",
          store: Raxx.Session.SignedCookie,
          secret_key_base: String.duplicate("squirrel", 8),
          salt: "epsom",
          domain: "other.example",
          max_age: 123_456_789,
          path: "some/path",
          secure: true,
          # Not sure it's possible to set http_only for false
          http_only: true,
          extra: "interesting"
        )

      {:ok, config: config}
    end

    test "custom options are sent in the response", %{config: config} do
      response =
        Raxx.response(:ok)
        |> Raxx.Session.embed(%{"user" => "other"}, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)

      assert map_size(cookie.attributes) == 7
      assert cookie.attributes.domain == "other.example"
      assert cookie.attributes.max_age == "123456789"
      assert cookie.attributes.path == "some/path"
      assert cookie.attributes.secure == true
      assert cookie.attributes.http_only == true
      assert cookie.attributes.extra == "interesting"
    end

    test "appropriate custom options are sent when expiring session", %{config: config} do
      response =
        Raxx.response(:ok)
        |> Raxx.Session.expire(config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)

      assert map_size(cookie.attributes) == 7
      assert cookie.attributes.domain == "other.example"
      assert cookie.attributes.expires == "Thu, 01 Jan 1970 00:00:00 GMT"
      assert cookie.attributes.max_age == "0"
      assert cookie.attributes.path == "some/path"
      assert cookie.attributes.secure == true
      assert cookie.attributes.http_only == true
      assert cookie.attributes.extra == "interesting"
    end
  end
end
