defmodule ExCheck.Check.Compiler do
  @moduledoc false

  alias ExCheck.{Config, Project}

  def compile(tools, opts) do
    {
      process_compiler(tools, opts),
      process_others(tools, opts)
    }
  end

  defp process_compiler(tools, opts) do
    compiler = List.keyfind(tools, :compiler, 0) || raise("compiler tool definition missing")
    compiler = prepare(compiler, opts)

    case compiler do
      {:pending, _} -> compiler
      _ -> {:pending, {:compiler, ["mix", "compile"], []}}
    end
  end

  defp process_others(tools, opts) do
    tools
    |> List.keydelete(:compiler, 0)
    |> Enum.sort_by(&get_order/1)
    |> filter_apps_in_umbrella()
    |> unwrap_recursive()
    |> map_recursive_dependents()
    |> Enum.map(&prepare(&1, opts))
    |> Enum.reject(&match?({:disabled, _}, &1))
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

  defp unwrap_recursive(tools) do
    Enum.reduce(tools, [], fn tool = {tool_name, tool_opts}, final_tools ->
      recursive = recursive?(tool_opts)

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

  defp map_recursive_dependents(tools) do
    recursive_tools =
      tools
      |> Enum.filter(&match?({{_, _}, _}, &1))
      |> Enum.group_by(fn {{name, _}, _} -> name end)

    Enum.reduce(recursive_tools, tools, fn recursive_tool, tools ->
      Enum.map(tools, fn {name, opts} ->
        opts = map_recursive_dependent(name, opts, recursive_tool)
        {name, opts}
      end)
    end)
  end

  defp map_recursive_dependent(name, opts, recursive_tool) do
    Keyword.update(opts, :deps, [], fn deps ->
      do_map_recursive_dependent(name, deps, recursive_tool)
    end)
  end

  defp do_map_recursive_dependent(name, deps, {recursive_name, recursive_instances}) do
    deps
    |> Enum.map(fn {dep, opts} ->
      if dep == recursive_name do
        case name do
          {_, app} -> {{recursive_name, app}, opts}
          _ -> Enum.map(recursive_instances, &{elem(&1, 0), opts})
        end
      else
        {dep, opts}
      end
    end)
    |> List.flatten()
  end

  defp recursive?(tool_opts) do
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

  defp prepare({name, tool_opts}, opts) do
    cond do
      disabled?(name, tool_opts, opts) ->
        {:disabled, name}

      failed_detection = find_failed_detection(name, tool_opts) ->
        prepare_failed_detection(name, failed_detection)

      tool_opts[:cd] && not File.dir?(tool_opts[:cd]) ->
        {:skipped, name, {:cd, tool_opts[:cd]}}

      true ->
        prepare_pending(name, tool_opts, opts)
    end
  end

  defp disabled?({name, _}, tool_opts, opts) do
    disabled?(name, tool_opts, opts)
  end

  defp disabled?(name, tool_opts, opts) do
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

  defp split_detection_opts({:elixir, version}), do: {{:elixir, version}, []}
  defp split_detection_opts({:package, name, opts}), do: {{:package, name}, opts}
  defp split_detection_opts({:package, name}), do: {{:package, name}, []}
  defp split_detection_opts({:file, name, opts}), do: {{:file, name}, opts}
  defp split_detection_opts({:file, name}), do: {{:file, name}, []}

  defp prepare_detection_base({:elixir, version}, _, _), do: {:elixir, version}

  defp prepare_detection_base({:package, name}, {_, app}, _), do: {:package, name, app}
  defp prepare_detection_base({:package, name}, _, _), do: {:package, name}

  defp prepare_detection_base({:file, name}, _, tool_opts) do
    filename =
      tool_opts
      |> Keyword.get(:cd, ".")
      |> Path.join(name)
      |> Path.relative_to(".")

    {:file, filename}
  end

  defp failed_detection?({:elixir, version}), do: not Version.match?(System.version(), version)
  defp failed_detection?({:package, name, app}), do: not Project.has_dep_in_app?(name, app)
  defp failed_detection?({:package, name}), do: not Project.has_dep?(name)
  defp failed_detection?({:file, name}), do: not File.exists?(name)

  defp prepare_failed_detection(name, failed_detection) do
    {base, opts} = failed_detection

    case Keyword.get(opts, :else, :skip) do
      :disable -> {:disabled, name}
      :skip -> {:skipped, name, base}
    end
  end

  defp prepare_pending(name, tool_opts, opts) do
    {mode, command} = pick_mode_and_command(tool_opts, opts)

    command =
      command
      |> command_to_array()
      |> postprocess_cmd(tool_opts)

    command_opts =
      tool_opts
      |> Keyword.take([:cd, :env, :deps])
      |> Keyword.put(:mode, mode)
      |> Keyword.put(:umbrella_parallel, get_in(tool_opts, [:umbrella, :parallel]))

    {:pending, {name, command, command_opts}}
  end

  defp pick_mode_and_command(tool_opts, opts) do
    cond do
      opts[:fix] && tool_opts[:fix] ->
        {:fix, tool_opts[:fix]}

      opts[:retry] && tool_opts[:retry] ->
        {:retry, tool_opts[:retry]}

      true ->
        {nil, Keyword.fetch!(tool_opts, :command)}
    end
  end

  defp postprocess_cmd(cmd, opts) do
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
    do: ["elixir", "--erl-config", enable_ansi_erl_cfg_path(), "-S", "mix" | arg]

  defp enable_ansi(["elixir" | arg], true),
    do: ["elixir", "--erl-config", enable_ansi_erl_cfg_path() | arg]

  defp enable_ansi(["mix" | arg], false),
    do: ["elixir", "-e", "Application.put_env(:elixir, :ansi_enabled, true)", "-S", "mix" | arg]

  defp enable_ansi(cmd, _),
    do: cmd

  defp enable_ansi_erl_cfg_path,
    do: Application.app_dir(:ex_check, ~w[priv enable_ansi enable_ansi.config])

  defp get_order({name, opts}),
    do: [Keyword.get(opts, :order, 0), Config.Default.tool_order(name)]
end
