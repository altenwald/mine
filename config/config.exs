import Config

config :mine,
  port: 4001,
  mines: 40,
  height: 16,
  width: 16,
  total_time: 999

config :mine, ecto_repos: [Mine.Repo]

config :number,
  delimit: [
    precision: 0,
    delimiter: ".",
    separator: ","
  ]

import_config("#{config_env()}.exs")
