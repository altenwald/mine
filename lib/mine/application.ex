defmodule Mine.Application do
  @moduledoc false

  use Application
  require Logger

  @default_port 4001

  def start(_type, _args) do
    import Supervisor.Spec

    # List all child processes to be supervised
    port_number = Application.get_env(:mine, :port, @default_port)

    {:ok, _} = EctoBootMigration.migrate(:mine)

    children = [
      # Start the Ecto repository
      supervisor(Mine.Repo, []),
      # Start the Registry for boards and the DynamicSupervisor
      {Registry, keys: :unique, name: Mine.Board.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Mine.Boards},
      # Start Plug for HTTP listener
      Plug.Cowboy.child_spec(scheme: :http,
                             plug: Mine.Router,
                             options: [port: port_number,
                                       dispatch: dispatch()]),
    ]

    Logger.info "[app] initiated application"

    opts = [strategy: :one_for_one, name: Mine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_, [
        {"/websession", Mine.Websocket, []},
        {:_, Plug.Cowboy.Handler, {Mine.Router, []}}
      ]}
    ]
  end
end
