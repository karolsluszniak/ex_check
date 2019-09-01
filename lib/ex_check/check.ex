defmodule ExCheck.Check do
  @moduledoc false

  alias ExCheck.{Command, Config, Printer}
  alias __MODULE__.{Compiler, Pipeline}

  def run(opts) do
    {tools, config_opts} = Config.load()
    opts = Keyword.merge(config_opts, opts)

    compile_and_run_tools(tools, opts)
  end

  defp compile_and_run_tools(tools, opts) do
    {compiler, others} = Compiler.compile(tools, opts)

    start_time = DateTime.utc_now()
    compiler_result = run_compiler(compiler)
    others_results = if run_others?(compiler_result), do: run_others(others, opts), else: []
    total_duration = DateTime.diff(DateTime.utc_now(), start_time)

    all_results = [compiler_result | others_results]
    failed_results = Enum.filter(all_results, &match?({:error, _, _}, &1))

    reprint_errors(failed_results)
    print_summary(all_results, total_duration, opts)
    maybe_set_exit_status(failed_results)
  end

  defp run_compiler(compiler) do
    run_tool(compiler)
  end

  @compile_warn_out "Compilation failed due to warnings while using the --warnings-as-errors option"

  defp run_others?(_compiler_result = {status, _, {_, output, _}}) do
    status == :ok or String.contains?(output, @compile_warn_out)
  end

  defp run_others(tools, opts) do
    {pending, skipped} = Enum.split_with(tools, &match?({:pending, _}, &1))
    {finished, broken} = run_tools(pending, opts)

    finished ++ skipped ++ broken
  end

  defp run_tools(tools, opts) do
    parallel = Keyword.get(opts, :parallel, true)

    tool_deps =
      Enum.map(tools, fn tool = {:pending, {name, _, opts}} ->
        deps = Keyword.get(opts, :run_after, [])
        {name, deps, tool}
      end)

    {finished, broken} =
      Pipeline.run(
        tool_deps,
        parallel: parallel,
        start_fn: &start_tool/1,
        collect_fn: &await_tool/1
      )

    broken = for {name, [dep | _], _} <- broken, do: {:skipped, name, {:run_after, dep}}

    {finished, broken}
  end

  defp run_tool(tool) do
    tool
    |> start_tool()
    |> await_tool()
  end

  defp start_tool({:pending, {name, cmd, opts}}) do
    opts = Keyword.merge(opts, stream: true, silenced: true, tint: IO.ANSI.faint())
    task = Command.async(cmd, opts)

    {:running, {name, cmd, opts}, task}
  end

  defp await_tool({:running, {name, cmd, opts}, task}) do
    Printer.info([:magenta, "=> running "] ++ format_tool_name(name))
    Printer.info()
    IO.write(IO.ANSI.faint())

    {output, code, duration} =
      task
      |> Command.unsilence()
      |> Command.await()

    if output_needs_padding?(output), do: Printer.info()
    IO.write(IO.ANSI.reset())

    status = if code == 0, do: :ok, else: :error

    {status, {name, cmd, opts}, {code, output, duration}}
  end

  defp output_needs_padding?(output) do
    not (String.match?(output, ~r/\n{2,}$/) or output == "")
  end

  defp reprint_errors(failed_tools) do
    Enum.each(failed_tools, fn {_, {name, _, _}, {_, output, _}} ->
      Printer.info([:red, "=> reprinting errors from "] ++ format_tool_name(name))
      Printer.info()
      IO.write(output)
      if output_needs_padding?(output), do: Printer.info()
    end)
  end

  defp print_summary(items, total_duration, opts) do
    Printer.info([:magenta, "=> finished in ", :bright, format_duration(total_duration)])
    Printer.info()

    items
    |> Enum.sort_by(&get_summary_item_order/1)
    |> Enum.each(&print_summary_item(&1, opts))

    Printer.info()
  end

  defp get_summary_item_order({:ok, {name, _, _}, _}), do: {0, normalize_tool_name(name)}
  defp get_summary_item_order({:error, {name, _, _}, _}), do: {1, normalize_tool_name(name)}
  defp get_summary_item_order({:skipped, name, _}), do: {2, normalize_tool_name(name)}

  defp normalize_tool_name(name = {_, _}), do: name
  defp normalize_tool_name(name), do: {name, 0}

  defp print_summary_item({:ok, {name, _, _}, {_, _, duration}}, _) do
    name = format_tool_name(name)
    took = format_duration(duration)
    Printer.info([:green, " ✓ ", name, " success in ", b(took)])
  end

  defp print_summary_item({:error, {name, _, _}, {code, _, duration}}, _) do
    name = format_tool_name(name)
    took = format_duration(duration)
    Printer.info([:red, " ✕ ", name, " error code ", b(code), " in ", b(took)])
  end

  defp print_summary_item({:skipped, name, reason}, opts) do
    if Keyword.get(opts, :skipped, true) do
      name = format_tool_name(name)
      reason = format_skip_reason(reason)
      Printer.info([:cyan, "   ", name, " skipped due to ", reason])
    end
  end

  defp format_skip_reason({:run_after, name}) do
    ["broken tool dependency ", format_tool_name(name)]
  end

  defp format_skip_reason({:package, name}) do
    ["missing package ", b(name)]
  end

  defp format_skip_reason({:package, name, app}) do
    ["missing package ", b(name), " in ", b(app)]
  end

  defp format_skip_reason({:file, name}) do
    ["missing file ", b(name)]
  end

  defp format_skip_reason({:cd, cd}) do
    ["missing directory ", b(cd)]
  end

  defp format_tool_name(name) when is_atom(name) do
    b(name)
  end

  defp format_tool_name({name, app}) when is_atom(name) do
    [b(name), " in ", b(app)]
  end

  defp b(inner) do
    [:bright, to_string(inner), :normal]
  end

  defp format_duration(secs) do
    min = div(secs, 60)
    sec = rem(secs, 60)
    sec_str = if sec < 10, do: "0#{sec}", else: "#{sec}"

    "#{min}:#{sec_str}"
  end

  defp maybe_set_exit_status(failed_tools) do
    if Enum.any?(failed_tools) do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end
end
