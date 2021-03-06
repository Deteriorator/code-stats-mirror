use Mix.Config

# Finally, we also include the path to a manifest
# containing the digested version of static files. This
# manifest is generated by the mix phoenix.digest task
# which you typically run after static files are built.
config :code_stats, CodeStatsWeb.Endpoint,
  # Load host and port settings from env
  load_from_system_env: true,
  cache_static_manifest: "priv/static/cache_manifest.json",

  # Required when using distillery releases
  server: true

# Do not print debug messages in production
config :logger, level: :error

config :appsignal, :config, active: true

# Finally import the config/prod.secret.exs
# which should be versioned separately.
import_config "prod.secret.exs"
