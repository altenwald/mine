defmodule Mine.BoardHelper do
  @moduledoc false
  alias Mine.Game.Board

  defp visibility(:hidden), do: "H"
  defp visibility(:flag), do: "F"
  defp visibility(:flag_error), do: "X"
  defp visibility(:show), do: "S"

  defp content(n) when n in 0..9, do: to_string(n)
  defp content(:mine), do: "M"

  @doc """
  Translate board to a text format.
  """
  def tr(%Board{} = board) do
    tr(Board.get_naive_cells(board))
  end

  def tr([[_ | _] | _] = table) do
    for row <- table do
      for {content, visibility} <- row do
        content(content) <> visibility(visibility)
      end
      |> Enum.join(" ")
      |> String.replace_suffix("", "\n")
    end
    |> Enum.join()
  end

  @doc """
  Translate board to a hidden text format.
  """
  def tr_hidden(%Board{} = board) do
    tr_hidden(Board.get_naive_cells(board))
  end

  def tr_hidden([[_ | _] | _] = table) do
    for row <- table do
      Enum.map_join(row, &hidden_cell/1)
      |> String.replace_suffix("", "\n")
    end
    |> Enum.join()
  end

  defp hidden_cell({_, :hidden}), do: "?"
  defp hidden_cell({_, :flag}), do: "F"
  defp hidden_cell({:mine, _}), do: "X"
  defp hidden_cell({0, _}), do: "_"
  defp hidden_cell({content, _}), do: to_string(content)
end
