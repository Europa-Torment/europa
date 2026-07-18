# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :europa,
  ecto_repos: [Europa.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :europa, EuropaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EuropaWeb.ErrorHTML, json: EuropaWeb.ErrorJSON],
    root_layout: {EuropaWeb.Layouts, :root}
  ],
  pubsub_server: Europa.PubSub,
  live_view: [signing_salt: "QIKDydtT"]

config :europa, Europa.Server.Chat, messages_limit: 150

config :europa, Europa.Server.PlanetManager, implementation: Europa.Server.Planet
config :europa, Europa.Server.PlayerManager, implementation: Europa.Server.Player

config :europa, Europa.Server,
  finish_game_on_server_exit: true,
  max_efficiency: 50,
  # 5 hours,
  inactivity_timeout_ms: 5 * 60 * 60 * 1000

config :europa, Europa.Server.Planet,
  view_distance: 16,
  min_view_distance: 3,
  generate_distance: 10,
  crop_land_size: 500_000,
  base_loot_generate_possibility: 5000,
  base_enemy_generate_possibility: 5000,
  enemy_view_distance: 6,
  enemy_move_possibility: [from: 85, to: 100],
  npc_generate_possibility: 5000,
  predefined_cluster_distance: 40,
  predefined_cluster_update_distance: 200,
  default_predefined_possibility: 70,
  predefined_cluster_possibility: 15

config :europa, Europa.Server.Planet.Predefined,
  templates_path: "/planet/",
  building: [
    enemy_generate_possibility: 100,
    loot_generate_possibility: 3,
    locked_door_possibility: 10,
    broken_building_possibility: 10,
    broken_wall_possibility: 5,
    burning_building_possibility: 7,
    burning_floor_possibility: 3
  ]

config :europa, Europa.Games,
  leaders_limit: 50,
  active_games_per_user_limit: 3

# 5 minutes
config :europa, Europa.Games.LeadersCache, ttl_ms: 5 * 60 * 1000

config :europa, :weapons,
  burst_bullets_per_shot: 3,
  max_accuracy: 40

config :europa, :game_params,
  disaster_year: 2152,
  craft_moves_count: 3,
  player: [
    warm_up_quantity: 25,
    max_weight: [
      from: 50,
      to: 65
    ],
    max_health: [
      from: 100,
      to: 150
    ],
    accuracy: [
      from: 5,
      to: 15
    ],
    efficiency: [
      from: 1,
      to: 5
    ],
    max_warm: [
      from: 40,
      to: 60
    ],
    hunger: [
      from: 0,
      to: 10
    ],
    thirst: [
      from: 0,
      to: 10
    ],
    max_thirst: 100,
    max_hunger: 100,
    max_radiation: 100,
    low_health_ratio: 0.3,
    aim_accuracy: 5,
    aim_mode_moves_penalty: 1
  ]

config :europa, Europa.Server.Characters, filename: "characters.json"

config :europa, Europa.Server.Compass,
  max_description_length: 50,
  max_targets: 50

config :europa, :control_bindings,
  move_up: %{keys: ["ArrowUp", "W", "w"], codes: ["KeyW", "ArrowUp"]},
  move_down: %{keys: ["ArrowDown", "S", "s"], codes: ["KeyS", "ArrowDown"]},
  move_left: %{keys: ["ArrowLeft", "A", "a"], codes: ["KeyA", "ArrowLeft"]},
  move_right: %{keys: ["ArrowRight", "D", "d"], codes: ["KeyD", "ArrowRight"]},
  interact: %{keys: ["E", "e"], codes: ["KeyE"]},
  loot: %{keys: ["L", "l"], codes: ["KeyL"]},
  inventory: %{keys: ["I", "i"], codes: ["KeyI"]},
  control_hints: %{keys: ["H", "h"], codes: ["KeyH"]},
  shoot: %{keys: [" ", "Space"], codes: ["Space"]},
  reload: %{keys: ["R", "r"], codes: ["KeyR"]},
  aim: %{keys: ["V", "v"], codes: ["KeyV"]},
  zoom: %{keys: ["Z", "z"], codes: ["KeyZ"]},
  compass: %{keys: ["C", "c"], codes: ["KeyC"]},
  close: %{keys: ["Escape"], codes: ["Escape"]}

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  europa: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  europa: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
