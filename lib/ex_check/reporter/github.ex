defmodule ExCheck.Reporter.Github do
  @moduledoc false

  # GitHub Actions workflow-command output. Passing/failing tools are rendered to the
  # workflow log: ok/skipped as one-liners, failures as collapsible `::group::` blocks
  # carrying their raw (ANSI-colored) output, which the GitHub log renderer displays.
  # A Markdown run summary is appended to the file named by `$GITHUB_STEP_SUMMARY`.
  #
  # This reporter writes to stdout directly (not via Reporter.emit/2) since the log has
  # to reach the live GitHub runner; `--output` is rejected for this format.

  @behaviour ExCheck.Reporter

  alias ExCheck.Reporter

  @impl true
  def report(results, total_duration, _opts) do
    token = gen_token()
    IO.write(log(results, token))
    write_step_summary(results, total_duration)
    :ok
  end

  @doc """
  Renders the workflow log for `results`. `token` scopes the `::stop-commands::` guard
  that wraps raw failure output so that any workflow-command-looking lines inside a
  tool's output can't be interpreted by the runner.
  """
  def log(results, token) do
    sorted = Enum.sort_by(results, &Reporter.summary_order/1)
    [Enum.map(sorted, &line(&1, token)), error_line(results)]
  end

  defp line({:ok, {name, _, _}, {_, _, duration}}, _token) do

    
    "✓ #{Reporter.tool_name_string(name)} success in #{Reporter.format_duration(duration)}\n"
  end

  defp line({:skipped, name, reason}, _token) do
    "⏭ #{Reporter.tool_name_string(name)} skipped (#{Reporter.skip_reason_string(reason)})\n"
  end

  defp line({:error, {name, cmd, _}, {code, output, _}}, token) do
    title = "✕ #{Reporter.tool_name_string(name)} — #{command(cmd)} (exit #{code})"

    [
      "::group::#{escape_data(title)}\n",
      "::stop-commands::#{token}\n",
      ensure_trailing_newline(output),
      "::#{token}::\n",
      "::endgroup::\n"
    ]
  end

  defp error_line(results) do
    failed =
      results
      |> Enum.filter(&match?({:error, _, _}, &1))
      |> Enum.sort_by(&Reporter.summary_order/1)
      |> Enum.map(fn {_, {name, _, _}, _} -> Reporter.tool_name_string(name) end)

    if failed == [] do
      []
    else
      "::error::#{escape_data("mix check failed: " <> Enum.join(failed, ", "))}\n"
    end
  end

  @doc "Escapes a workflow-command data payload (message body)."
  def escape_data(str) do
    str
    |> String.replace("%", "%25")
    |> String.replace("\r", "%0D")
    |> String.replace("\n", "%0A")
  end

  @doc "Escapes a workflow-command property value (stricter than data)."
  def escape_property(str) do
    str
    |> escape_data()
    |> String.replace(":", "%3A")
    |> String.replace(",", "%2C")
  end

  @doc "Appends the Markdown run summary to `$GITHUB_STEP_SUMMARY`, or skips silently if unset."
  # sobelow_skip ["Traversal.FileModule"]
  def write_step_summary(results, total_duration) do
    case System.get_env("GITHUB_STEP_SUMMARY") do
      path when is_binary(path) and path != "" ->
        File.write!(path, summary_md(results, total_duration), [:append])

      _ ->
        :ok
    end

    :ok
  end

  defp summary_md(results, total_duration) do
    rows =
      results
      |> Enum.sort_by(&Reporter.summary_order/1)
      |> Enum.map(&summary_row/1)

    [
      "## mix check\n\n",
      "| Check | Status | Duration |\n",
      "| --- | --- | --- |\n",
      rows,
      "\nTotal: #{Reporter.format_duration(total_duration)}\n"
    ]
  end

  defp summary_row({:ok, {name, _, _}, {_, _, duration}}) do
    "| #{Reporter.tool_name_string(name)} | ✅ | #{Reporter.format_duration(duration)} |\n"
  end

  defp summary_row({:error, {name, _, _}, {_, _, duration}}) do
    "| #{Reporter.tool_name_string(name)} | ❌ | #{Reporter.format_duration(duration)} |\n"
  end

  defp summary_row({:skipped, name, _reason}) do
    "| #{Reporter.tool_name_string(name)} | ⏭ | — |\n"
  end

  defp command(cmd), do: cmd |> List.wrap() |> Enum.join(" ")

  defp ensure_trailing_newline(""), do: "\n"

  defp ensure_trailing_newline(str),
    do: if(String.ends_with?(str, "\n"), do: str, else: str <> "\n")

  defp gen_token, do: Base.encode16(:crypto.strong_rand_bytes(8))
end
