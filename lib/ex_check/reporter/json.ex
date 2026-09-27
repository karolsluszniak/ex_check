defmodule ExCheck.Reporter.Json do
  @moduledoc false

  # Strict, single valid JSON object describing the whole run. For tools/scripts;
  # pairs naturally with `--output PATH`. Failed checks carry their (escaped) output.

  @behaviour ExCheck.Reporter

  alias ExCheck.Diagnostics
  alias ExCheck.JSON
  alias ExCheck.Reporter

  @impl true
  def report(results, total_duration, opts) do
    Reporter.emit(JSON.encode(build(results, total_duration)), opts)
  end

  @doc false
  def build(results, total_duration) do
    failed = Enum.count(results, &match?({:error, _, _}, &1))

    %{
      status: if(failed == 0, do: "ok", else: "error"),
      duration_s: total_duration,
      passed: Enum.count(results, &match?({:ok, _, _}, &1)),
      failed: failed,
      skipped: Enum.count(results, &match?({:skipped, _, _}, &1)),
      checks: results |> Enum.sort_by(&Reporter.summary_order/1) |> Enum.map(&check/1)
    }
  end

  defp check({:ok, _, _} = result), do: run_check(result)

  defp check({:error, _, {_, output, _}} = result) do
    Map.merge(run_check(result), %{
      output: Reporter.strip_ansi(output),
      diagnostics: result |> Diagnostics.extract() |> Enum.map(&diagnostic/1)
    })
  end

  defp check({:skipped, name, reason}) do
    {name, app} = Reporter.split_name(name)
    %{name: name, app: app, status: "skipped", reason: Reporter.skip_reason_string(reason)}
  end

  # Fields shared by every tool that actually ran (ok or error).
  defp run_check({status, {name, cmd, _}, {code, _, duration}}) do
    {name, app} = Reporter.split_name(name)

    %{
      name: name,
      app: app,
      status: Atom.to_string(status),
      command: Reporter.command(cmd),
      exit_code: code,
      duration_s: duration
    }
  end

  defp diagnostic(%Diagnostics.Diagnostic{} = diag) do
    %{
      file: diag.file,
      line: diag.line,
      column: diag.column,
      message: diag.message,
      severity: Atom.to_string(diag.severity)
    }
  end
end
