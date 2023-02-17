defmodule Mine.Application do
  @moduledoc false

  use Application
  require Logger

  @impl Application
  @doc false
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Mine.Repo,
      # Supervisor
      Mine.Game,
      # Start Plug for HTTP listener
      Mine.Http
    ]

    Logger.info("[app] initiated application")

    opts = [strategy: :one_for_one, name: Mine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
