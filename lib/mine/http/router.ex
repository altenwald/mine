defmodule Mine.Http.Router do
  @moduledoc """
  Router for handling the incoming HTTP requests. The router is part
  of the Plug configuration, you can see the module `Mine.Application`
  for further information.
  """
  use Plug.Router

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

  match _ do
    send_resp(conn, 404, "oops")
  end
end
