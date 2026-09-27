defmodule ExCheck.Diagnostics.ExUnit do
  @moduledoc false

  # Parses ExUnit failure headers: a `  N) <headline>` line followed by a
  # `     test/foo_test.exs:line` location. Failures without a file:line (e.g. a
  # crashing `setup_all`) simply don't match and are skipped.

  @behaviour ExCheck.Diagnostics

  alias ExCheck.Diagnostics.Diagnostic

  @failure ~r/^\s{2}\d+\) (.+)\n\s+([^\s:]+\.exs):(\d+)/m

  @impl true
  def parse(text) do
    @failure
    |> Regex.scan(text)
    |> Enum.map(fn [_, message, file, line] ->
      %Diagnostic{file: file, line: String.to_integer(line), message: String.trim(message)}
    end)
  end
end
