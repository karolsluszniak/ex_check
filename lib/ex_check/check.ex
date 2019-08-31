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
      |> filter_apps_in_umbrella()
      |> unwrap_recursive_tools()
      |> map_recursive_tool_dependents()
      |> Enum.sort_by(&get_tool_order/1)
      |> Enum.map(&prepare_tool(&1, opts))
      |> Enum.reject(&match?({:disabled, _}, &1))
      |> Enum.split_with(&match?({:pending, _}, &1))

    {finished, broken} = run_tools(pending, opts)

    new_skipped =
      Enum.map(broken, fn {name, [dep | _], _} ->
        {:skipped, name, {:run_after, dep}}
      end)

    finished ++ skipped ++ new_skipped
  end

  defp filter_apps_in_umbrella(tools) do
    app = Project.config()[:app]

    if Project.in_umbrella?() do
      Enum.filter(tools, fn {_, tool_opts} ->
        enabled_apps = get_in(tool_opts, [:umbrella, :apps])
        !enabled_apps || Enum.member?(enabled_apps, app)
      end)
    else
      tools
    end
  end

  defp unwrap_recursive_tools(tools) do
    Enum.reduce(tools, [], fn tool = {tool_name, tool_opts}, final_tools ->
      recursive = tool_recursive?(tool_opts)

      if recursive and Project.umbrella?() do
        actual_apps_paths = Project.apps_paths()
        enabled_apps = get_in(tool_opts, [:umbrella, :apps])

        apps_paths =
          if enabled_apps,
            do: Map.take(actual_apps_paths, enabled_apps),
            else: actual_apps_paths

        tool_instances =
          Enum.map(apps_paths, fn {app_name, app_dir} ->
            final_tool_opts = Keyword.update(tool_opts, :cd, app_dir, &Path.join(app_dir, &1))
            {{tool_name, app_name}, final_tool_opts}
          end)

        final_tools ++ tool_instances
      else
        final_tools ++ [tool]
      end
    end)
  end

  defp map_recursive_tool_dependents(tools) do
    recursive_tools =
      tools
      |> Enum.filter(&match?({{_, _}, _}, &1))
      |> Enum.group_by(fn {{name, _}, _} -> name end)

    Enum.reduce(recursive_tools, tools, fn recursive_tool, dependent_tools ->
      Enum.map(dependent_tools, fn {name, opts} ->
        opts =
          Keyword.update(opts, :run_after, [], fn deps ->
            map_recursive_tool_dependent(name, deps, recursive_tool)
          end)

        {name, opts}
      end)
    end)
  end

  defp map_recursive_tool_dependent(name, deps, {recursive_name, recursive_instances}) do
    deps
    |> Enum.map(fn dep ->
      if dep == recursive_name do
        case name do
          {_, app} ->
            {recursive_name, app}

          _ ->
            Enum.map(recursive_instances, &elem(&1, 0))
        end
      else
        dep
      end
    end)
    |> List.flatten()
  end

  defp tool_recursive?(tool_opts) do
    case get_in(tool_opts, [:umbrella, :recursive]) do
      nil ->
        tool_opts
        |> Keyword.fetch!(:command)
        |> command_to_array()
        |> mix_task_recursive?()

      recursive ->
        recursive
    end
  end

  defp command_to_array(cmd) when is_list(cmd), do: cmd
  defp command_to_array(cmd), do: String.split(cmd, " ")

  defp mix_task_recursive?(["mix", task | _]) do
    case Mix.Task.get(task) do
      nil -> false
      task_module -> Mix.Task.recursive(task_module)
    end
  end

  defp mix_task_recursive?(_) do
    true
  end

  defp prepare_tool({name, tool_opts}, opts) do
    cond do
      tool_disabled?(name, tool_opts, opts) ->
        {:disabled, name}

      failed_detection = find_failed_detection(name, tool_opts) ->
        {base, opts} = failed_detection

        if Keyword.get(opts, :disable, false),
          do: {:disabled, name},
          else: {:skipped, name, base}

      tool_opts[:cd] && not File.dir?(tool_opts[:cd]) ->
        {:skipped, name, {:cd, tool_opts[:cd]}}

      true ->
        command = Keyword.fetch!(tool_opts, :command)
        command_opts = Keyword.take(tool_opts, [:cd, :env, :enable_ansi, :run_after])

        {:pending, {name, command, command_opts}}
    end
  end

  defp tool_disabled?({name, _}, tool_opts, opts) do
    tool_disabled?(name, tool_opts, opts)
  end

  defp tool_disabled?(name, tool_opts, opts) do
    Keyword.get(tool_opts, :enabled, true) == false ||
      (Keyword.has_key?(opts, :only) && !Enum.any?(opts, &(&1 == {:only, name}))) ||
      Enum.any?(opts, fn i -> i == {:except, name} end)
  end

  defp find_failed_detection(name, tool_opts) do
    tool_opts
    |> Keyword.get(:detect, [])
    |> Enum.map(&split_detection_opts/1)
    |> Enum.map(fn {base, opts} -> {prepare_detection_base(base, name, tool_opts), opts} end)
    |> Enum.find(fn {base, _} -> failed_detection?(base) end)
  end

  defp split_detection_opts({:package, name, opts}), do: {{:package, name}, opts}
  defp split_detection_opts({:package, name}), do: {{:package, name}, []}
  defp split_detection_opts({:file, name, opts}), do: {{:file, name}, opts}
  defp split_detection_opts({:file, name}), do: {{:file, name}, []}

  defp prepare_detection_base({:package, name}, {_, app}, _), do: {:package, name, app}
  defp prepare_detection_base({:package, name}, _, _), do: {:package, name}

  defp prepare_detection_base({:file, name}, _, tool_opts) do
    filename =
      tool_opts
      |> Keyword.get(:cd, ".")
      |> Path.join(name)

    {:file, filename}
  end

  defp failed_detection?({:package, name, app}) do
    not Project.has_dep_in_app?(name, app)
  end

  defp failed_detection?({:package, name}) do
    not Project.has_dep?(name)
  end

  defp failed_detection?({:file, name}) do
    not File.exists?(name)
  end

  defp get_tool_order({_, opts}), do: Keyword.get(opts, :order, 0)

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

  defp prepare_tool_cmd(cmd, opts) do
    if Keyword.get(opts, :enable_ansi, true) do
      supports_erl_config = Version.match?(System.version(), ">= 1.9.0")

      cmd
      |> command_to_array()
      |> enable_ansi(supports_erl_config)
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
    ["broken tool dependency ", :bright, format_tool_name(name), :normal]
  end

  defp format_skip_reason({:package, name}) do
    ["missing package ", :bright, to_string(name), :normal]
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
