defmodule ExCheck.Reporter.Agent do
  @moduledoc false

  # Hybrid format for AI agents: a one-line JSON status header (the machine-readable
  # verdict) followed by raw, unescaped output blocks for failed checks only, wrapped
  # in stable delimiters so the report survives any chatter Mix prints before us.

  @behaviour ExCheck.Reporter

  alias ExCheck.Diagnostics
  alias ExCheck.JSON
  alias ExCheck.Reporter

  @begin_marker "<<<EX_CHECK_REPORT>>>"
  @end_marker "<<<END_EX_CHECK_REPORT>>>"

  @impl true
  def report(results, total_duration, opts) do
    failed = Enum.filter(results, &match?({:error, _, _}, &1))

    report_iodata = [
      @begin_marker,
      "\n",
      JSON.encode(header(results, failed, total_duration)),
      "\n",
      Enum.map(failed, &failure_block/1),
      @end_marker
    ]

    Reporter.emit(report_iodata, opts)
  end

  defp header(results, failed, total_duration) do
    passed = Enum.count(results, &match?({:ok, _, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _, _}, &1))

    failed_checks =
      failed
      |> Enum.sort_by(&Reporter.summary_order/1)
      |> Enum.map(fn {_, {name, _, _}, _} -> Reporter.tool_name_string(name) end)

    %{
      status: if(failed == [], do: "ok", else: "error"),
      passed: passed,
      failed: length(failed),
      skipped: skipped,
      duration_s: total_duration,
      failed_checks: failed_checks,
      diagnostics: diagnostics(failed)
    }
  end

  defp diagnostics(failed) do
    Enum.flat_map(failed, fn {_, {name, _, _}, _} = result ->
      Enum.map(Diagnostics.extract(result), fn diag ->
        %{
          check: Reporter.tool_name_string(name),
          file: diag.file,
          line: diag.line,
          message: diag.message,
          severity: Atom.to_string(diag.severity)
        }
      end)
    end)
  end

  defp failure_block({_, {name, cmd, _}, {code, output, _}}) do
    name = Reporter.tool_name_string(name)
    output = output |> Reporter.strip_ansi() |> ensure_trailing_newline()

    ["=== FAILED: #{name} — #{Reporter.command(cmd)} (exit #{code}) ===\n", output]
  end

  defp ensure_trailing_newline(""), do: ""

  defp ensure_trailing_newline(str) do
    if String.ends_with?(str, "\n"), do: str, else: str <> "\n"
  end
end
