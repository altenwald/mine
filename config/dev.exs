import Config

# Make sure this directory exists
config :mnesia, dir: 'priv/data/mnesia'

config :mine, Mine.Repo, adapter: EctoMnesia.Adapter
