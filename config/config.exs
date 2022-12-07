import Config

config :mine,
  port: 4001,
  mines: 40,
  height: 16,
  width: 16,
  total_time: 999

config :mine, ecto_repos: [Mine.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

# Make sure this directory exists
config :mnesia, dir: 'priv/data/mnesia'

config :mine, Mine.Repo, adapter: EctoMnesia.Adapter

config :number,
  delimit: [
    precision: 0,
    delimiter: ".",
    separator: ","
  ]
