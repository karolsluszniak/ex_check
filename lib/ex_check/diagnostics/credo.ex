defmodule ExCheck.Diagnostics.Credo do
  @moduledoc false

  # Parses Credo's default output format: an issue headline (`[R] ↘ message`) followed
  # on the next line by a `file.ex:line:col` location. Walked statefully because the two
  # halves live on separate lines. A custom `--format` in the user's config yields `[]`.

  @behaviour ExCheck.Diagnostics

  alias ExCheck.Diagnostics
  alias ExCheck.Diagnostics.Diagnostic

  @issue ~r/\[([RCWFDE])\]\s+\S\s+(.+?)\s*$/u
  @location ~r/([^\s#]+\.exs?):(\d+)(?::(\d+))?/

  @impl true
  def parse(text) do
    text
    |> String.split("\n")
    |> Enum.reduce({[], nil}, &walk/2)
    |> elem(0)
    |> Enum.reverse()
  end

  defp walk(line, {acc, pending}) do
    case Regex.run(@issue, line) do
      [_, category, message] -> {acc, {severity(category), message}}
      nil -> walk_location(line, acc, pending)
    end
  end

  defp walk_location(_line, acc, nil), do: {acc, nil}

  defp walk_location(line, acc, pending) do
    case Regex.run(@location, line) do
      nil -> {acc, pending}
      loc -> {[emit(loc, pending) | acc], nil}
    end
  end

  defp emit(loc, {severity, message}) do
    {file, line, column} = Diagnostics.parse_location(loc)
    %Diagnostic{file: file, line: line, column: column, message: message, severity: severity}
  end

  defp severity("W"), do: :warning
  defp severity(_), do: :error
end
