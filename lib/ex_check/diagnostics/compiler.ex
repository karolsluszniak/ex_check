defmodule ExCheck.Diagnostics.Compiler do
  @moduledoc false

  # Parses `mix compile` diagnostics. Handles the Elixir >= 1.16 block format (a
  # `warning:`/`error:` headline followed by a `└─ file:line:col` trailer) and falls
  # back to the legacy `    file.ex:line` location line for older output.

  @behaviour ExCheck.Diagnostics

  alias ExCheck.Diagnostics.Diagnostic

  @anchor ~r/^[ \t]*(warning|error): (.+)$/
  @location ~r/└─\s+([^\s:]+):(\d+)(?::(\d+))?/
  @legacy ~r/^\s+([^\s:]+\.exs?):(\d+)(?::(\d+))?/m

  @impl true
  def parse(text) do
    text
    |> String.split("\n")
    |> chunk_blocks()
    |> Enum.map(&block_to_diagnostic/1)
  end

  defp chunk_blocks(lines) do
    {blocks, current} =
      Enum.reduce(lines, {[], nil}, fn line, {blocks, current} ->
        case Regex.run(@anchor, line) do
          [_, severity, message] ->
            {prepend(blocks, current), {severity, message, []}}

          _ ->
            case current do
              nil -> {blocks, nil}
              {severity, message, acc} -> {blocks, {severity, message, [line | acc]}}
            end
        end
      end)

    blocks |> prepend(current) |> Enum.reverse()
  end

  defp prepend(blocks, nil), do: blocks
  defp prepend(blocks, block), do: [block | blocks]

  defp block_to_diagnostic({severity, message, acc}) do
    {file, line, column} = acc |> Enum.reverse() |> Enum.join("\n") |> locate()

    %Diagnostic{
      file: file,
      line: line,
      column: column,
      message: String.trim(message),
      severity: severity(severity)
    }
  end

  defp locate(text) do
    cond do
      match = Regex.run(@location, text) -> parse_loc(match)
      match = Regex.run(@legacy, text) -> parse_loc(match)
      true -> {nil, nil, nil}
    end
  end

  defp parse_loc([_, file, line]), do: {file, to_int(line), nil}
  defp parse_loc([_, file, line, ""]), do: {file, to_int(line), nil}
  defp parse_loc([_, file, line, column]), do: {file, to_int(line), to_int(column)}

  defp severity("warning"), do: :warning
  defp severity(_), do: :error

  defp to_int(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end
end
