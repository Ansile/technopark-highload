defmodule ConfigReader do
  @moduledoc false

  def parseToMap(path) do
    file = File.read!(path)
    strings = file |> String.split("\n")
    configLines = for string <- strings, do: string |> String.split()

    for line <- configLines, into: %{}, do: { Enum.at(line, 0), Enum.at(line, 1) }
  end
end
