defmodule Mine.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :mine,
    adapter: Ecto.Adapters.SQLite3
end
