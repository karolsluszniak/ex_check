defmodule ExCheck.Diagnostics.Credo do
  @moduledoc false

  # Parses Credo's default output format: an issue headline (`[R] ↘ message`) followed
  # on the next line by a `file.ex:line:col` location. Walked statefully because the two
  # halves live on separate lines. A custom `--format` in the user's config yields `[]`.

  @behaviour ExCheck.Diagnostics

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
      [_, category, message] ->
        {acc, {severity(category), message}}

      nil ->
        case pending && Regex.run(@location, line) do
          loc when is_list(loc) -> {[emit(loc, pending) | acc], nil}
          _ -> {acc, pending}
        end
    end
  end

  defp emit(loc, {severity, message}) do
    {file, line, column} = parse_loc(loc)
    %Diagnostic{file: file, line: line, column: column, message: message, severity: severity}
  end

  defp parse_loc([_, file, line]), do: {file, to_int(line), nil}
  defp parse_loc([_, file, line, ""]), do: {file, to_int(line), nil}
  defp parse_loc([_, file, line, column]), do: {file, to_int(line), to_int(column)}

  defp severity("W"), do: :warning
  defp severity(_), do: :error

  defp to_int(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end
end
