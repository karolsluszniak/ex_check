defmodule ExCheck.Config do
  @moduledoc false

  alias ExCheck.{Printer, Project}

  @curated_tools [
    {:compiler, command: "mix compile --warnings-as-errors --force"},
    {:formatter, command: "mix format --check-formatted", require_files: [".formatter.exs"]},
    {:ex_unit, command: "mix test", require_files: ["test/test_helper.exs"]},
    {:credo, command: "mix credo", require_deps: [:credo]},
    {:sobelow, command: "mix sobelow --exit --skip", require_deps: [:sobelow]},
    {:dialyzer, command: "mix dialyzer --halt-exit-status", require_deps: [:dialyxir]},
    {:ex_doc, command: "mix docs", require_deps: [:ex_doc]}
  ]

  @default_config [
    parallel: true,
    exit_status: true,
    skipped: true,
    tools: @curated_tools
  ]

  @option_list [:parallel, :exit_status, :skipped]

  @config_filename ".check.exs"

  def get_opts(config) do
    Keyword.take(config, @option_list)
  end

  def get_tools(config) do
    Keyword.fetch!(config, :tools)
  end

  # sobelow_skip ["RCE.CodeModule"]
  def load do
    user_home_dir = System.user_home()
    user_dirs = if user_home_dir, do: [user_home_dir], else: []
    project_dirs = Project.get_mix_parent_dirs()
    dirs = user_dirs ++ project_dirs

    Enum.reduce(dirs, @default_config, fn next_config_dir, config ->
      next_config_filename =
        next_config_dir
        |> Path.join(@config_filename)
        |> Path.expand()

      if File.exists?(next_config_filename) do
        {next_config, _} = Code.eval_file(next_config_filename)
        merge_config(config, next_config)
      else
        config
      end
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
  defp merge_tool({name, opts}, {name, false}), do: {name, merge_tool_opts(opts, enabled: false)}
  defp merge_tool({name, opts}, {name, next_opts}), do: {name, merge_tool_opts(opts, next_opts)}

  defp merge_tool_opts(opts, next_opts) do
    merged_opts = Keyword.merge(opts, next_opts)

    env = opts[:env]
    next_env = next_opts[:env]

    if env && next_env do
      Keyword.put(merged_opts, :env, Map.merge(env, next_env))
    else
      merged_opts
    end
  end

  @generated_config """
  [
    ## all available options with default values (see `mix check` docs for description)
    # skipped: true,
    # exit_status: true,
    # parallel: true,

    ## list of tools (see `mix check` docs for defaults)
    tools: [
      ## curated tools may be disabled (e.g. the check for compilation warnings)
      # {:compiler, enabled: false},

      ## ...or adjusted (e.g. use one-line formatter for more compact credo output)
      # {:credo, command: "mix credo --format oneline"},

      ## ...or reordered (e.g. to see output from ex_unit before others)
      {:ex_unit, order: -1}

      ## custom new tools may be added (mix tasks or arbitrary commands)
      # {:my_mix_task, command: "mix release", env: %{"MIX_ENV" => "prod"}},
      # {:my_arbitrary_tool, command: "npm test", cd: "assets"},
      # {:my_arbitrary_script, command: ["my_script", "argument with spaces"], cd: "scripts"}
    ]
  ]
  """

  # sobelow_skip ["Traversal.FileModule"]
  def generate do
    target_path =
      Project.get_mix_root_dir()
      |> Path.join(@config_filename)
      |> Path.expand()

    formatted_path = Path.relative_to_cwd(target_path)

    if File.exists?(target_path) do
      Printer.info([:yellow, "* ", :bright, formatted_path, :normal, " already exists, skipped"])
    else
      Printer.info([:green, "* creating ", :bright, formatted_path])

      File.write!(target_path, @generated_config)
    end
  end
end
