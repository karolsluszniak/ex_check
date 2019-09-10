defmodule ExCheck.Config.Loader do
  @moduledoc false

  alias ExCheck.Config.Default, as: DefaultConfig
  alias ExCheck.Project

  @config_filename ".check.exs"
  @option_list [:parallel, :skipped]

  def load do
    user_home_dir = System.user_home()
    user_dirs = if user_home_dir, do: [user_home_dir], else: []
    project_root_dir = Project.get_mix_root_dir()
    dirs = user_dirs ++ [project_root_dir]

    default_config = normalize_config(DefaultConfig.get())
    config = load_from_dirs(dirs, default_config)
    tools = Keyword.fetch!(config, :tools)
    opts = Keyword.take(config, @option_list)

    {tools, opts}
  end

  # sobelow_skip ["RCE.CodeModule"]
  defp load_from_dirs(dirs, default_config) do
    Enum.reduce(dirs, default_config, fn next_config_dir, config ->
      next_config_filename =
        next_config_dir
        |> Path.join(@config_filename)
        |> Path.expand()

      if File.exists?(next_config_filename) do
        {next_config, _} = Code.eval_file(next_config_filename)
        next_config = normalize_config(next_config)

        merge_config(config, next_config)
      else
        config
      end
    end)
  end

  defp normalize_config(config) do
    Keyword.update(config, :tools, [], fn tools ->
      Enum.map(tools, fn
        {name, opts = [{_, _} | _]} ->
          {name, opts}

        {name, enabled} when is_boolean(enabled) ->
          {name, enabled: enabled}

        {name, command} when is_binary(command) ->
          {name, command: command}

        {name, command = [arg | _]} when is_binary(arg) ->
          {name, command: command}

        {name, command, opts = [{_, _} | _]} when is_binary(command) ->
          {name, Keyword.put(opts, :command, command)}

        {name, command = [arg | _], opts = [{_, _} | _]} when is_binary(arg) ->
          {name, Keyword.put(opts, :command, command)}
      end)
    end)
  end

  defp merge_config(config, next_config) do
    config_opts = Keyword.take(config, @option_list)
    next_config_opts = Keyword.take(next_config, @option_list)
    merged_opts = Keyword.merge(config_opts, next_config_opts)

    config_tools = Keyword.fetch!(config, :tools)
    next_config_tools = Keyword.get(next_config, :tools, [])

    merged_tools =
      Enum.reduce(next_config_tools, config_tools, fn next_tool, tools ->
        next_tool_name = elem(next_tool, 0)
        tool = List.keyfind(tools, next_tool_name, 0)
        merged_tool = merge_tool(tool, next_tool)

        List.keystore(tools, next_tool_name, 0, merged_tool)
      end)

    Keyword.put(merged_opts, :tools, merged_tools)
  end

  defp merge_tool(tool, next_tool)
  defp merge_tool(nil, next_tool), do: next_tool
  defp merge_tool({name, opts}, {name, next_opts}), do: {name, merge_tool_opts(opts, next_opts)}

  defp merge_tool_opts(opts, next_opts) do
    opts
    |> Keyword.merge(next_opts)
    |> Keyword.put(:env, Map.merge(opts[:env] || %{}, next_opts[:env] || %{}))
    |> Keyword.put(:umbrella, Keyword.merge(opts[:umbrella] || [], next_opts[:umbrella] || []))
  end
end
