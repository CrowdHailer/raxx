use Mix.Config

config :raxx,
  extra_statuses: [{422, "Unprocessable Entity"}],
  silence_logger_warning: true,
  silence_view_warning: true
