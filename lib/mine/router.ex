defmodule Mine.Router do
  use Plug.Router

  plug Plug.Logger, log: :debug
  plug Plug.Static, from: {:mine, "priv/static"}, at: "/"
  plug Plug.Parsers, parsers: [:json],
                     pass: ["text/*"],
                     json_decoder: Jason
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "world")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
