defmodule Mine.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Registry, keys: :unique, name: Mine.Board.Registry},
      Plug.Cowboy.child_spec(scheme: :http,
                             plug: Mine.Router,
                             options: [port: 4001,
                                       dispatch: dispatch()]),
    ]

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
