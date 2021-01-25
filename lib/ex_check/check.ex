defmodule ExCheck.Check do
  @moduledoc false

  alias ExCheck.Check.Compiler
  alias ExCheck.Check.Pipeline
  alias ExCheck.Command
  alias ExCheck.Config
  alias ExCheck.Manifest
  alias ExCheck.Printer

  def run(opts) do
    {tools, config_opts} = Config.load(file: opts[:config])

    opts =
      config_opts
      |> Keyword.merge(opts)
      |> maybe_toggle_retry_mode()
      |> Manifest.convert_retry_to_only()

    compile_and_run_tools(tools, opts)
  end

  defp maybe_toggle_retry_mode(opts) do
    with false <- Keyword.has_key?(opts, :retry),
         tools when tools != [] and tools != [:compiler] <- Manifest.get_failed_tools(opts) do
      Printer.info([:cyan, "=> retrying automatically: "] ++ Enum.map(tools, &format_tool_name/1))
      Printer.info()

      opts ++ [{:retry, true}]
    else
      _ -> opts
    end
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
    Manifest.save(all_results, opts)
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
    {finished, skipped_runtime} = run_tools(pending, opts)

    finished ++ skipped ++ skipped_runtime
  end

  defp run_tools(tools, opts) do
    {finished, broken} =
      Pipeline.run(
        tools,
        throttle_fn: &throttle_tools(&1, &2, &3, opts),
        start_fn: &start_tool/1,
        collect_fn: &await_tool/1
      )

    skipped = filter_broken_skipped(broken, finished)

    {finished, skipped}
  end

  defp filter_broken_skipped(broken, finished) do
    broken
    |> Enum.map(fn tool = {:pending, {name, _, _}} ->
      deps = get_unsatisfied_deps(tool, finished)

      dep_names =
        deps
        |> Enum.filter(fn {_, opts} -> opts[:else] != :disable end)
        |> Enum.map(&elem(&1, 0))

      Enum.any?(dep_names) && {:skipped, name, {:deps, dep_names}}
    end)
    |> Enum.filter(& &1)
  end

  defp run_tool(tool) do
    tool
    |> start_tool()
    |> await_tool()
  end

  defp throttle_tools(pending, running, finished, opts) do
    parallel = Keyword.get(opts, :parallel, true)

    pending
    |> filter_no_deps(finished)
    |> throttle_parallel(running, parallel)
    |> throttle_umbrella_parallel(running)
  end

  defp filter_no_deps(pending, finished) do
    Enum.filter(pending, fn tool ->
      get_unsatisfied_deps(tool, finished) == []
    end)
  end

  defp get_unsatisfied_deps({:pending, {_, _, opts}}, finished) do
    opts
    |> Keyword.get(:deps, [])
    |> Enum.map(fn
      dep = {_, opts} when is_list(opts) -> dep
      name -> {name, []}
    end)
    |> Enum.reject(&satisfied_dep?(&1, finished))
  end

  defp satisfied_dep?({name, opts}, finished) do
    status = Keyword.get(opts, :status, :any)
    finished_match = Enum.find(finished, fn {_, {fin_name, _, _}, _} -> fin_name == name end)

    finished_match && satisfied_dep_status?(status, finished_match)
  end

  defp satisfied_dep_status?(list, finished) when is_list(list) do
    Enum.any?(list, &satisfied_dep_status?(&1, finished))
  end

  defp satisfied_dep_status?(:any, _), do: true
  defp satisfied_dep_status?(:ok, {:ok, _, _}), do: true
  defp satisfied_dep_status?(:error, {:error, _, _}), do: true
  defp satisfied_dep_status?(code, {_, _, {actual, _, _}}) when is_integer(code), do: code == actual
  defp satisfied_dep_status?(_, _), do: false

  defp throttle_parallel(selected, _, true), do: selected
  defp throttle_parallel([first_selected | _], [], false), do: [first_selected]
  defp throttle_parallel(_, _, false), do: []

  defp throttle_umbrella_parallel(selected, running) do
    running_names = Enum.map(running, &extract_tool_name/1)

    Enum.reduce(selected, [], fn next = {:pending, {name, _, opts}}, approved ->
      approved_names = Enum.map(approved, &extract_tool_name/1)

      if opts[:umbrella_parallel] == false &&
           (includes_umbrella_instance_from_same_app?(running_names, name) ||
              includes_umbrella_instance_from_same_app?(approved_names, name)) do
        approved
      else
        approved ++ [next]
      end
    end)
  end

  defp extract_tool_name({:pending, {name, _, _}}), do: name

  defp includes_umbrella_instance_from_same_app?(names, match_name) do
    Enum.any?(names, &umbrella_instance_from_same_app?(&1, match_name))
  end

  defp umbrella_instance_from_same_app?({name, _}, {name, _}), do: true
  defp umbrella_instance_from_same_app?(_, _), do: false

  defp start_tool({:pending, {name, cmd, opts}}) do
    opts = Keyword.merge(opts, stream: true, silenced: true, tint: IO.ANSI.faint())
    task = Command.async(cmd, opts)

    {:running, {name, cmd, opts}, task}
  end

  defp await_tool({:running, {name, cmd, opts}, task}) do
    mode_suffix = if mode = opts[:mode], do: [" in ", b(mode), " mode"], else: []

    Printer.info([:magenta, "=> running "] ++ format_tool_name(name) ++ mode_suffix)
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

  defp print_summary_item({:ok, {name, _, opts}, {_, _, duration}}, _) do
    name = format_tool_name(name)
    took = format_duration(duration)
    mode = if mode = opts[:mode], do: [" ", to_string(mode)], else: []

    Printer.info([:green, " ✓ ", name, mode, " success in ", b(took)])
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

  defp format_skip_reason({:elixir, version}) do
    ["Elixir version = ", System.version(), ", not ", version]
  end

  defp format_skip_reason({:deps, [name | _]}) do
    ["unsatisfied dependency ", format_tool_name(name)]
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
