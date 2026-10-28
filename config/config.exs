import Config

config :mine,
  port: if(config_env() == :test, do: 0, else: 4001),
  mines: 40,
  height: 16,
  width: 16,
  total_time: 999

config :mine, ecto_repos: [Mine.Repo]

config :mine, Mine.Repo,
  database: Path.expand("../data/mine_#{config_env()}.db", __DIR__),
  pool_size: 1,
  busy_timeout: 5_000
