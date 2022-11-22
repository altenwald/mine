defmodule Mine.Game do
  @moduledoc """
  Supervisor to handle the dynamic supervisor for creating the games,
  and the registry where we can find the games.
  """
  use Supervisor

  @doc false
  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Supervisor
  @doc false
  def init([]) do
    children = [
      # Start the Registry for boards and the DynamicSupervisor
      {Registry, keys: :unique, name: Mine.Board.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Mine.Boards}
    ]

    options = [strategy: :one_for_all]
    Supervisor.init(children, options)
  end

  @doc """
  Start a new process under the dynamic supervisor.
  """
  @spec start(Mine.Board.board_id()) :: DynamicSupervisor.on_start_child()
  def start(board) do
    DynamicSupervisor.start_child(Mine.Boards, {Mine.Board.OnePlayer, board})
  end
end
