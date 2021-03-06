use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :code_stats, CodeStatsWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :code_stats, CodeStats.Repo,
  username: "postgres",
  password: "postgres",
  database: "code_stats_ci",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox
