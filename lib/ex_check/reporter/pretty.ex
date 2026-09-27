defmodule ExCheck.Reporter.Pretty do
  @moduledoc false

  @behaviour ExCheck.Reporter

  alias ExCheck.Printer
  alias ExCheck.Reporter

  @impl true
  def report(results, total_duration, opts) do
    failed = Enum.filter(results, &match?({:error, _, _}, &1))

    reprint_errors(failed)
    print_summary(results, total_duration, opts)
  end

  defp reprint_errors(failed_tools) do
    Enum.each(failed_tools, fn {_, {name, _, _}, {_, output, _}} ->
      Printer.info([:red, "=> reprinting errors from "] ++ Reporter.format_tool_name(name))
      Printer.info()
      IO.write(output)
      if Reporter.output_needs_padding?(output), do: Printer.info()
    end)
  end

  defp print_summary(items, total_duration, opts) do
    Printer.info([:magenta, "=> finished in ", :bright, Reporter.format_duration(total_duration)])
    Printer.info()

    items
    |> Enum.sort_by(&Reporter.summary_order/1)
    |> Enum.each(&print_summary_item(&1, opts))

    Printer.info()

    :ok
  end

  defp print_summary_item({:ok, {name, _, opts}, {_, _, duration}}, _) do
    name = Reporter.format_tool_name(name)
    took = Reporter.format_duration(duration)
    mode = if mode = opts[:mode], do: [" ", to_string(mode)], else: []

    Printer.info([:green, " ✓ ", name, mode, " success in ", Reporter.bright(took)])
  end

  defp print_summary_item({:error, {name, _, _}, {code, _, duration}}, _) do
    name = Reporter.format_tool_name(name)
    took = Reporter.format_duration(duration)

    Printer.info([
      :red,
      " ✕ ",
      name,
      " error code ",
      Reporter.bright(code),
      " in ",
      Reporter.bright(took)
    ])
  end

  defp print_summary_item({:skipped, name, reason}, opts) do
    if Keyword.get(opts, :skipped, true) do
      name = Reporter.format_tool_name(name)
      reason = format_skip_reason(reason)
      Printer.info([:cyan, "   ", name, " skipped due to ", reason])
    end
  end

  defp format_skip_reason({:elixir, version}) do
    ["Elixir version = ", System.version(), ", not ", version]
  end

  defp format_skip_reason({:deps, [name | _]}) do
    ["unsatisfied dependency ", Reporter.format_tool_name(name)]
  end

  defp format_skip_reason({:halted, name}) do
    ["halted after failure of ", Reporter.format_tool_name(name)]
  end

  defp format_skip_reason({:package, name}) do
    ["missing package ", Reporter.bright(name)]
  end

  defp format_skip_reason({:package, name, app}) do
    ["missing package ", Reporter.bright(name), " in ", Reporter.bright(app)]
  end

  defp format_skip_reason({:file, name}) do
    ["missing file ", Reporter.bright(name)]
  end

  defp format_skip_reason({:cd, cd}) do
    ["missing directory ", Reporter.bright(cd)]
  end
end
