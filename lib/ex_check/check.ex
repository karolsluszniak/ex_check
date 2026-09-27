defmodule ExCheck.Check do
  @moduledoc false

  alias ExCheck.Check.Compiler
  alias ExCheck.Check.Pipeline
  alias ExCheck.Command
  alias ExCheck.Config
  alias ExCheck.Manifest
  alias ExCheck.Printer
  alias ExCheck.Reporter

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
      tool_names =
        tools
        |> Enum.with_index()
        |> Enum.map(fn
          {tool, 0} -> Reporter.format_tool_name(tool)
          {tool, _} -> [" ", Reporter.format_tool_name(tool)]
        end)

      if live?(opts) do
        Printer.info([:cyan, "=> retrying automatically: "] ++ tool_names)
        Printer.info()
      end

      opts ++ [{:retry, true}]
    else
      _ -> opts
    end
  end

  defp compile_and_run_tools(tools, opts) do
    {compiler, others} = Compiler.compile(tools, opts)

    start_time = DateTime.utc_now()
    compiler_result = run_tool(compiler, opts)
    others_results = if run_others?(compiler_result), do: run_others(others, opts), else: []
    total_duration = DateTime.diff(DateTime.utc_now(), start_time)

    all_results = [compiler_result | others_results]
    failed_results = Enum.filter(all_results, &match?({:error, _, _}, &1))

    reporter = Reporter.resolve(Keyword.get(opts, :format, :pretty))
    reporter.report(all_results, total_duration, opts)
    Manifest.save(all_results, opts)
    maybe_set_exit_status(failed_results)
  end

  defp live?(opts), do: Keyword.get(opts, :format, :pretty) == :pretty

  @compile_warn_out "Compilation failed due to warnings while using the --warnings-as-errors option"

  defp run_others?({status, _, {_, output, _}} = _compiler_result) do
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
        start_fn: &start_tool(&1, opts),
        collect_fn: &await_tool(&1, opts)
      )

    skipped =
      if failed_name = halted_by(finished, opts) do
        Enum.map(broken, fn {:pending, {name, _, _}} ->
          {:skipped, name, {:halted, failed_name}}
        end)
      else
        filter_broken_skipped(broken, finished)
      end

    {finished, skipped}
  end

  defp halted_by(finished, opts) do
    with true <- Keyword.get(opts, :halt_on_failure, false),
         {:error, {name, _, _}, _} <- Enum.find(finished, &match?({:error, _, _}, &1)) do
      name
    else
      _ -> nil
    end
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

  defp run_tool(tool, opts) do
    tool
    |> start_tool(opts)
    |> await_tool(opts)
  end

  defp throttle_tools(pending, running, finished, opts) do
    if halted_by(finished, opts), do: [], else: throttle_pending(pending, running, finished, opts)
  end

  defp throttle_pending(pending, running, finished, opts) do
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

  defp start_tool({:pending, {name, cmd, tool_opts}}, opts) do
    cmd_opts =
      if live?(opts) do
        Keyword.merge(tool_opts, stream: true, silenced: true, tint: IO.ANSI.faint())
      else
        Keyword.merge(tool_opts, stream: false, silenced: true)
      end

    task = Command.async(cmd, cmd_opts)

    {:running, {name, cmd, cmd_opts}, task}
  end

  defp await_tool({:running, {name, cmd, tool_opts}, task}, opts) do
    if live?(opts) do
      await_tool_live(name, cmd, tool_opts, task)
    else
      {output, code, duration} = Command.await(task)
      {tool_status(code), {name, cmd, tool_opts}, {code, output, duration}}
    end
  end

  defp await_tool_live(name, cmd, tool_opts, task) do
    mode_suffix = if mode = tool_opts[:mode], do: [" in ", Reporter.bright(mode), " mode"], else: []

    Printer.info([:magenta, "=> running "] ++ Reporter.format_tool_name(name) ++ mode_suffix)
    Printer.info()
    IO.write(IO.ANSI.faint())

    {output, code, duration} =
      task
      |> Command.unsilence()
      |> Command.await()

    if Reporter.output_needs_padding?(output), do: Printer.info()
    IO.write(IO.ANSI.reset())

    {tool_status(code), {name, cmd, tool_opts}, {code, output, duration}}
  end

  defp tool_status(0), do: :ok
  defp tool_status(_), do: :error

  defp maybe_set_exit_status(failed_tools) do
    if Enum.any?(failed_tools) do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end
end
