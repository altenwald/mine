defmodule Mine.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :mine,
    adapter: EctoMnesia.Adapter
end
