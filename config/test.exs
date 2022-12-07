import Config

config :mnesia, dir: '/tmp/mnesia'

config :mine, Mine.Repo, adapter: EctoMnesia.Adapter
