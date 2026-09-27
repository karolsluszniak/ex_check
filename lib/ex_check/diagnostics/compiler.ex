defmodule ExCheck.Diagnostics.Compiler do
  @moduledoc false

  # Parses `mix compile` diagnostics. Handles the Elixir >= 1.16 block format (a
  # `warning:`/`error:` headline followed by a `└─ file:line:col` trailer) and falls
  # back to the legacy `    file.ex:line` location line for older output. The output is
  # split in front of every headline; text before the first one has no headline and is
  # dropped.

  @behaviour ExCheck.Diagnostics

  alias ExCheck.Diagnostics
  alias ExCheck.Diagnostics.Diagnostic

  @anchor ~r/^[ \t]*(warning|error): (.+)$/m
  @block_start ~r/^(?=[ \t]*(?:warning|error): )/m
  @location ~r/└─\s+([^\s:]+):(\d+)(?::(\d+))?/
  @legacy ~r/^\s+([^\s:]+\.exs?):(\d+)(?::(\d+))?/m

  @impl true
  def parse(text) do
    @block_start
    |> Regex.split(text)
    |> Enum.flat_map(&block_to_diagnostic/1)
  end

  defp block_to_diagnostic(block) do
    case Regex.run(@anchor, block) do
      [_, severity, message] ->
        {file, line, column} = locate(block)

        [
          %Diagnostic{
            file: file,
            line: line,
            column: column,
            message: String.trim(message),
            severity: severity(severity)
          }
        ]

      nil ->
        []
    end
  end

  defp locate(text) do
    cond do
      match = Regex.run(@location, text) -> Diagnostics.parse_location(match)
      match = Regex.run(@legacy, text) -> Diagnostics.parse_location(match)
      true -> {nil, nil, nil}
    end
  end

  defp severity("warning"), do: :warning
  defp severity(_), do: :error
end
