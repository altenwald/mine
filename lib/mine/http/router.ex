defmodule Mine.Http.Router do
  @moduledoc """
  Router for handling the incoming HTTP requests. The router is part
  of the Plug configuration, you can see the module `Mine.Application`
  for further information.
  """
  use Plug.Router

  plug(Plug.Head)
  plug(Plug.Logger, log: :debug)
  plug(Plug.Static, from: {:mine, "priv/static"}, at: "/")

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["text/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    priv_dir = :code.priv_dir(:mine)
    send_file(conn, 200, "#{priv_dir}/static/index.html")
  end

  get "/websession" do
    conn
    |> WebSockAdapter.upgrade(Mine.Http.Websocket, [remote_ip: remote_ip(conn)], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  @doc """
  Returns the client address, trusting forwarded addresses only from configured proxies.
  """
  @spec remote_ip(Plug.Conn.t()) :: String.t()
  def remote_ip(conn) do
    address =
      conn |> Plug.Conn.get_peer_data() |> Map.fetch!(:address) |> :inet.ntoa() |> to_string()

    trusted_proxies = Application.get_env(:mine, :trusted_proxies, ["127.0.0.1", "::1"])

    if address in trusted_proxies do
      case get_req_header(conn, "x-forwarded-for") do
        [forwarded | _] -> forwarded
        [] -> address
      end
    else
      address
    end
  end
end
