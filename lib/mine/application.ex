defmodule Mine.Application do
  @moduledoc false

  use Application
  require Logger

  @impl Application
  @doc false
  def start(_type, _args) do
    {:ok, _} = EctoBootMigration.migrate(:mine)

    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Mine.Repo,
      # Start the Registry for boards and the DynamicSupervisor
      {Registry, keys: :unique, name: Mine.Board.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Mine.Boards},
      # Start Plug for HTTP listener
      Mine.Http
    ]

    Logger.info("[app] initiated application")

    opts = [strategy: :one_for_one, name: Mine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
