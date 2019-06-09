defmodule Mine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_mines 40
  @default_height 16
  @default_width 16

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Mine.Worker.start_link(arg)
      {Mine.Board, [@default_width, @default_height, @default_mines]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
