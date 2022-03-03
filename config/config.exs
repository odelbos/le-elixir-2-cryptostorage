import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n"

# -----

# Import environment specific config.
# Must remain at the bottom to overrides the above configuration.
import_config "#{config_env()}.exs"
