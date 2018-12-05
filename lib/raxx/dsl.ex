defmodule MyApp do
  use Raxx.Router.DSL

  @stack :api
  "user/:user_id" ~> ShowUser

  @stack :web
  "user/:user_id" ~> ShowUser
  "user/:user_id" ~> ShowUser
  "user/*rest" ~> ShowUser

  {"user/:user_id", :GET} <> ShowUser

  {"user/:user_id", :GET} <> ShowUser

  action("user/:user_id" ~> ShowUser)
  action("user/:user_id", ShowUser)
  # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/pages/Operators.md
end
