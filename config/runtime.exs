import Config

if proxies = System.get_env("TRUSTED_PROXIES") do
  config :mine, trusted_proxies: String.split(proxies, ",", trim: true)
end

if port = System.get_env("PORT") do
  config :mine, port: String.to_integer(port)
end

# Production data must live outside the release directory.
if config_env() == :prod do
  database = System.fetch_env!("DATABASE_PATH")
  config :mine, Mine.Repo, database: Path.expand(database)
else
  if database = System.get_env("DATABASE_PATH") do
    config :mine, Mine.Repo, database: Path.expand(database)
  end
end
