import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :europa, Europa.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "europa_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :europa, EuropaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7ylQsmV1OlFsjuD4UCvDeetpVLtLf1LW0ekxudoN3Vi0Yqo/kbCUO4gAR0QoFl0J",
  server: false

config :europa, Europa.Tools.TextGenerator, texts_path: "/texts_templates/test/"

config :europa, Europa.Server.Planet.Predefined, templates_path: "/planet/test/"

config :europa, Europa.Server.Planet.Predefined,
  building: [
    enemy_generate_possibility: 100_000_000,
    loot_generate_possibility: 1
  ]

# Changing will break tests
config :europa, Europa.Server.Planet,
  initial_game_field: [width: 20, height: 20],
  view_distance: 5,
  generate_distance: 1,
  enemy_view_distance: 3,
  # Keep 100% possibility to tests consistency
  enemy_move_possibility: [from: 10, to: 10]

config :europa, Europa.Server, finish_game_on_server_exit: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
