defmodule ExCheck.Check do
  @moduledoc false

  alias ExCheck.{Command, Config, Printer, Project}

  def run(opts) do
    config = Config.load()
    tools_from_config = Config.get_tools(config)
    opts_from_config = Config.get_opts(config)
    opts_merged = Keyword.merge(opts_from_config, opts)

    compile_and_run_tools(tools_from_config, opts_merged)
  end

  defp compile_and_run_tools(tools, opts) do
    start_time = DateTime.utc_now()
    compiler_result = run_compiler(tools, opts)
    other_results = if run_others?(compiler_result), do: run_others(tools, opts), else: []
    total_duration = DateTime.diff(DateTime.utc_now(), start_time)
    all_results = [compiler_result | other_results]
    failed_results = Enum.filter(all_results, &match?({:error, _, _}, &1))

    reprint_errors(failed_results)
    print_summary(all_results, total_duration, opts)
    maybe_set_exit_status(failed_results)
  end

  defp run_compiler(tools, opts) do
    compiler = List.keyfind(tools, :compiler, 0) || raise("compiler tool definition missing")
    compiler = prepare_tool(compiler, opts)
    compiler = with {:disabled, _} <- compiler, do: {:pending, {:compiler, "mix compile", []}}

    run_tool(compiler)
  end

  @compile_warn_out "Compilation failed due to warnings while using the --warnings-as-errors option"

  defp run_others?(_compiler_result = {status, _, {_, output, _}}) do
    status == :ok or String.contains?(output, @compile_warn_out)
  end

  defp run_others(tools, opts) do
    tools =
      tools
      |> List.keydelete(:compiler, 0)
      |> Enum.sort_by(&get_tool_order/1)
      |> Enum.map(&prepare_tool(&1, opts))
      |> Enum.reject(&match?({:disabled, _}, &1))

    if Keyword.get(opts, :parallel, true) do
      tools
      |> Enum.map(&start_tool/1)
      |> Enum.map(&await_tool/1)
    else
      Enum.map(tools, &run_tool/1)
    end
  end

  defp prepare_tool({name, config}, opts) do
    command = Keyword.fetch!(config, :command)
    command_opts = Keyword.take(config, [:cd, :env, :enable_ansi])
    require_deps = Keyword.get(config, :require_deps, [])
    require_files = Keyword.get(config, :require_files, [])

    cond do
      Keyword.get(config, :enabled, true) == false ->
        {:disabled, name}

      Keyword.has_key?(opts, :only) && !Enum.any?(opts, &(&1 == {:only, name})) ->
        {:disabled, name}

      Enum.any?(opts, fn i -> i == {:except, name} end) ->
        {:disabled, name}

      missing_dep = find_missing_dep(require_deps) ->
        {:skipped, name, ["missing dependency ", :bright, to_string(missing_dep), :normal]}

      missing_file = find_missing_file(require_files) ->
        {:skipped, name, ["missing file ", :bright, missing_file, :normal]}

      true ->
        {:pending, {name, command, command_opts}}
    end
  end

  defp find_missing_dep(require_deps) do
    Enum.find(require_deps, &(not Project.has_dep?(&1)))
  end

  defp find_missing_file(require_files) do
    dirs = Project.get_mix_child_dirs()

    Enum.find(require_files, fn file ->
      not Enum.any?(dirs, fn dir ->
        dir
        |> Path.join(file)
        |> File.exists?()
      end)
    end)
  end

  defp get_tool_order({_, opts}), do: Keyword.get(opts, :order, 0)
  defp get_tool_order(_), do: 0

  defp run_tool(tool) do
    tool
    |> start_tool()
    |> await_tool()
  end

  @ansi_code_regex ~r/(\x1b\[[0-9;]*m)/

  defp start_tool({:pending, {name, cmd, opts}}) do
    stream = fn out ->
      out
      |> String.replace(@ansi_code_regex, "\\1" <> IO.ANSI.faint())
      |> IO.write()
    end

    env = Keyword.get(opts, :env, %{})
    {final_cmd, final_env} = prepare_tool_cmd(cmd, env, opts)
    final_opts = Keyword.merge(opts, stream: stream, silenced: true, env: final_env)
    task = Command.async(final_cmd, final_opts)

    {:running, {name, cmd, opts}, task}
  end

  defp start_tool(inactive_tool) do
    inactive_tool
  end

  defp prepare_tool_cmd(cmd, env, opts) when is_binary(cmd) do
    cmd
    |> String.split(" ")
    |> prepare_tool_cmd(env, opts)
  end

  defp prepare_tool_cmd(cmd = ["mix" | task], env, opts) do
    if Keyword.get(opts, :enable_ansi, true) do
      enable_ansi(task, env)
    else
      {cmd, env}
    end
  end

  defp prepare_tool_cmd(cmd, env, _opts) do
    {cmd, env}
  end

  @enable_ansi_eval ~S"""
  Application.put_env(:elixir, :ansi_enabled, true, persistent: true)
  Mix.Task.reenable("app.start")
  """

  # Mix tasks executed by `mix check` are not run in a TTY and will by default not print ANSI
  # characters in their output - which means no colors, no bold etc. This makes the tool output
  # (e.g. assertion diffs from ex_unit) less useful. We explicitly enable ANSI to fix that.
  defp enable_ansi(task = [task_name | _], env) do
    # In order to enable ANSI, we must wrap the original mix task in `mix do` which will mean that
    # its preferred CLI env won't be respected by default. We explicitly set MIX_ENV to fix that.
    final_env = Map.put_new_lazy(env, "MIX_ENV", fn -> "#{Project.get_task_env(task_name)}" end)

    {["mix", "do", "run", "--no-start", "-e", @enable_ansi_eval, "," | task], final_env}
  end

  defp await_tool({:running, {name, cmd, opts}, task}) do
    Printer.info([:magenta, "=> running ", :bright, to_string(name)])
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

  defp await_tool(inactive_tool) do
    inactive_tool
  end

  defp output_needs_padding?(output) do
    not (String.match?(output, ~r/\n{2,}$/) or output == "")
  end

  defp reprint_errors(failed_tools) do
    Enum.each(failed_tools, fn {_, {name, _, _}, {_, output, _}} ->
      Printer.info([:red, "=> reprinting errors from ", :bright, to_string(name)])
      Printer.info()
      IO.write(output)
      if output_needs_padding?(output), do: Printer.info()
    end)
  end

  defp print_summary(items, total_duration, opts) do
    Printer.info([:magenta, "=> finished in ", :bright, format_duration(total_duration)])
    Printer.info()

    items
    |> Enum.sort()
    |> Enum.each(&print_summary_item(&1, opts))

    Printer.info()
  end

  defp print_summary_item({:ok, {name, _, _}, {_, _, duration}}, _) do
    took = format_duration(duration)
    name = to_string(name)
    Printer.info([:green, " ✓ ", :bright, name, :normal, " success in ", :bright, took])
  end

  defp print_summary_item({:error, {name, _, _}, {code, _, duration}}, _) do
    n = :normal
    b = :bright
    name = to_string(name)
    code_string = to_string(code)
    took = format_duration(duration)
    Printer.info([:red, " ✕ ", b, name, n, " error code ", b, code_string, n, " in ", b, took])
  end

  defp print_summary_item({:skipped, name, reason}, opts) do
    if Keyword.get(opts, :skipped, true) do
      Printer.info([:cyan, "   ", :bright, to_string(name), :normal, " skipped due to "] ++ reason)
    end
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
