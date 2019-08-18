defmodule ExCheck.Check do
  @moduledoc false

  alias ExCheck.{Command, Config, GraphExecutor, Printer, Project}

  def run(opts) do
    config = Config.load()
    tools_from_config = Config.get_tools(config)
    opts_from_config = Config.get_opts(config)
    opts_merged = Keyword.merge(opts_from_config, opts)

    compile_and_run_tools(tools_from_config, opts_merged)
  end

  defp compile_and_run_tools(tools, opts) do
    start_time = DateTime.utc_now()
    compiler = run_compiler(tools, opts)
    finished = if run_others?(compiler), do: run_others(tools, opts), else: []
    total_duration = DateTime.diff(DateTime.utc_now(), start_time)

    all_results = [compiler | finished]
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
    {pending, skipped} =
      tools
      |> List.keydelete(:compiler, 0)
      |> Enum.sort_by(&get_tool_order/1)
      |> Enum.map(&prepare_tool(&1, opts))
      |> Enum.reject(&match?({:disabled, _}, &1))
      |> Enum.split_with(&match?({:pending, _}, &1))

    {finished, broken} = run_tools(pending, opts)

    new_skipped =
      Enum.map(broken, fn {name, [unresolved_dep | _], _} ->
        {:skipped, name, ["broken tool dependency ", :bright, to_string(unresolved_dep), :normal]}
      end)

    finished ++ skipped ++ new_skipped
  end

  # To better understand what's happening here and what exactly `GraphExecutor` does consider that
  # if we wouldn't care about tool dependencies we could use following `run_tools` implementation:
  #
  #     defp run_tools(tools, opts) do
  #       if Keyword.get(opts, :parallel, true) do
  #         {tools |> Enum.map(&start_tool/1) |> Enum.map(&await_tool/1), []}
  #       else
  #         {Enum.map(tools, &run_tool/1), []}
  #       end
  #     end
  #
  # Refer to `GraphExecutor` code comments for more info.
  defp run_tools(tools, opts) do
    parallel = Keyword.get(opts, :parallel, true)

    tool_deps =
      Enum.map(tools, fn tool = {:pending, {name, _, opts}} ->
        deps = Keyword.get(opts, :run_after, [])
        {name, deps, tool}
      end)

    GraphExecutor.run(
      tool_deps,
      parallel: parallel,
      start_fn: &start_tool/1,
      collect_fn: &await_tool/1
    )
  end

  defp prepare_tool({name, tool_opts}, opts) do
    cond do
      tool_disabled?(name, tool_opts, opts) ->
        {:disabled, name}

      failed_detection = find_failed_detection(tool_opts) ->
        {base, opts} = failed_detection

        if Keyword.get(opts, :disable, false),
          do: {:disabled, name},
          else: {:skipped, name, get_failed_detection_message(base)}

      true ->
        command = Keyword.fetch!(tool_opts, :command)
        command_opts = Keyword.take(tool_opts, [:cd, :env, :enable_ansi, :run_after])

        {:pending, {name, command, command_opts}}
    end
  end

  defp tool_disabled?(name, tool_opts, opts) do
    Keyword.get(tool_opts, :enabled, true) == false ||
      (Keyword.has_key?(opts, :only) && !Enum.any?(opts, &(&1 == {:only, name}))) ||
      Enum.any?(opts, fn i -> i == {:except, name} end)
  end

  defp find_failed_detection(tool_opts) do
    tool_opts
    |> Keyword.get(:detect, [])
    |> Enum.map(&split_detection_opts/1)
    |> Enum.find(fn {base, _} -> failed_detection?(base) end)
  end

  defp split_detection_opts({:package, name, opts}), do: {{:package, name}, opts}
  defp split_detection_opts({:package, name}), do: {{:package, name}, []}
  defp split_detection_opts({:file, name, opts}), do: {{:file, name}, opts}
  defp split_detection_opts({:file, name}), do: {{:file, name}, []}

  defp failed_detection?({:package, name}) do
    not Project.has_dep?(name)
  end

  defp failed_detection?({:file, name}) do
    dirs = Project.get_mix_child_dirs()

    not Enum.any?(dirs, fn dir ->
      dir
      |> Path.join(name)
      |> File.exists?()
    end)
  end

  defp get_failed_detection_message({:package, name}) do
    ["missing package ", :bright, to_string(name), :normal]
  end

  defp get_failed_detection_message({:file, name}) do
    ["missing file ", :bright, name, :normal]
  end

  defp get_tool_order({_, opts}), do: Keyword.get(opts, :order, 0)

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
    final_cmd = prepare_tool_cmd(cmd, opts)
    final_opts = Keyword.merge(opts, stream: stream, env: env, silenced: true)
    task = Command.async(final_cmd, final_opts)

    {:running, {name, cmd, opts}, task}
  end

  defp prepare_tool_cmd(cmd, opts) when is_binary(cmd) do
    cmd
    |> String.split(" ")
    |> prepare_tool_cmd(opts)
  end

  defp prepare_tool_cmd(cmd, opts) do
    if Keyword.get(opts, :enable_ansi, true) do
      supports_erl_config = Version.match?(System.version(), ">= 1.9.0")
      enable_ansi(cmd, supports_erl_config)
    else
      cmd
    end
  end

  # Elixir commands executed by `mix check` are not run in a TTY and will by default not print ANSI
  # characters in their output - which means no colors, no bold etc. This makes the tool output
  # (e.g. assertion diffs from ex_unit) less useful. We explicitly enable ANSI to fix that.
  defp enable_ansi(["mix" | arg], true),
    do: ["elixir", "--erl-config", erl_cfg_path(), "-S", "mix" | arg]

  defp enable_ansi(["elixir" | arg], true),
    do: ["elixir", "--erl-config", erl_cfg_path() | arg]

  defp enable_ansi(["mix" | arg], false),
    do: ["elixir", "-e", "Application.put_env(:elixir, :ansi_enabled, true)", "-S", "mix" | arg]

  defp enable_ansi(cmd, _),
    do: cmd

  defp erl_cfg_path, do: Application.app_dir(:ex_check, ~w[priv enable_ansi enable_ansi.config])

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
