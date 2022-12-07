defmodule Mine.Http do
  @moduledoc """
  Definition for the HTTP endpoint.
  """

  @default_port 4001
  @default_num_acceptors 10

  @doc false
  def child_spec([]) do
    port_number = Application.get_env(:mine, :port, @default_port)
    num_acceptors = Application.get_env(:mine, :num_acceptors, @default_num_acceptors)

    Plug.Cowboy.child_spec(
      scheme: :http,
      plug: Mine.Router,
      options: [
        port: port_number,
        dispatch: dispatch(),
        transport_options: [num_acceptors: num_acceptors]
      ]
    )
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websession", Mine.Http.Websocket, []},
         {:_, Plug.Cowboy.Handler, {Mine.Http.Router, []}}
       ]}
    ]
  end
end
