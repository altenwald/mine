defmodule Mine.Repo do
  use Ecto.Repo,
    otp_app: :mine,
    adapter: EctoMnesia.Adapter
end
