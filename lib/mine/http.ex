defmodule Mine.Http do
  @moduledoc "HTTP endpoint served by Bandit."

  @doc false
  def child_spec([]) do
    [plug: Mine.Http.Router, port: Application.get_env(:mine, :port, 4001)]
    |> Bandit.child_spec()
    |> Map.put(:id, __MODULE__)
  end
end
