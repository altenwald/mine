defmodule Mine.ANSI do
  @moduledoc false

  @doc false
  def clean(text) when is_binary(text) do
    Regex.replace(~r"\e\[[0-9]+[Jm]", text, "")
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> then(&(&1 <> "\n"))
  end
end
