import Config

get_atom = fn key, default ->
  if value = System.get_env(key) do
    String.to_atom(value)
  else
    default
  end
end

get_charlist = fn key, default ->
  if value = System.get_env(key) do
    String.to_charlist(value)
  else
    default
  end
end

config :mnesia, dir: get_charlist.("MNESIA_DIR", 'DATA')

config :mine, Mine.Repo,
  adapter: EctoMnesia.Adapter,
  host: get_atom.("MNESIA_HOST", :"mine@127.0.0.1"),
  storage_type: get_atom.("MNESIA_STORAGE_TYPE", :disc_copies)
