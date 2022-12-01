defmodule Mine.BoardHelper do
  @moduledoc false
  alias Mine.Game.Board

  defp visibility(:hidden), do: "H"
  defp visibility(:flag), do: "F"
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
  def tr_hidden(board) do
    for row <- Board.get_naive_cells(board) do
      for {content, visibility} <- row do
        cond do
          visibility == :hidden -> "?"
          visibility == :flag -> "F"
          content == :mine -> "X"
          content == 0 -> "_"
          :else -> to_string(content)
        end
      end
      |> Enum.join()
      |> String.replace_suffix("", "\n")
    end
    |> Enum.join()
  end
end
