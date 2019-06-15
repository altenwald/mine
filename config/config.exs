use Mix.Config

config :etag_plug,
  generator: ETag.Generator.SHA1,
  methods: ["GET"],
  status_codes: [200]

config :mine, port: 4001,
              mines: 40,
              height: 16,
              width: 16,
              total_time: 999

config :mine, ecto_repos: [Mine.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

config :mnesia, dir: 'priv/data/mnesia' # Make sure this directory exists

config :mine, Mine.Repo,
  adapter: EctoMnesia.Adapter
