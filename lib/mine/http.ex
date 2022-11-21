defmodule Mine.Http do
  @moduledoc """
  Definition for the HTTP endpoint.
  """

  @default_port 4001

  @doc false
  def child_spec([]) do
    port_number = Application.get_env(:mine, :port, @default_port)

    Plug.Cowboy.child_spec(
      scheme: :http,
      plug: Mine.Router,
      options: [port: port_number, dispatch: dispatch()]
    )
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websession", Mine.Websocket, []},
         {:_, Plug.Cowboy.Handler, {Mine.Router, []}}
       ]}
    ]
  end
end
