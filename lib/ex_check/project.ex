defmodule ExCheck.Project do
  @moduledoc false

  def config do
    Mix.Project.config()
  end

  def has_dep?(name) do
    config()
    |> Keyword.fetch!(:deps)
    |> List.keymember?(name, 0)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def get_task_env(task) when is_binary(task) do
    task
    |> String.to_atom()
    |> get_task_env()
  end

  def get_task_env(task) do
    config()[:preferred_cli_env][task] || Mix.Task.preferred_cli_env(task) || :dev
  end

  def check_runner_available?(env) do
    own_dep =
      config()
      |> Keyword.fetch!(:deps)
      |> List.keyfind(:ex_check, 0)

    opts =
      case own_dep do
        {_, _, opts} when is_list(opts) -> opts
        {_, opts} when is_list(opts) -> opts
        _ -> []
      end

    only = opts[:only]

    Mix.Project.config()[:app] == :ex_check || (own_dep && (!only || Enum.member?(only, env))) ||
      false
  end

  def get_mix_root_dir do
    if in_umbrella?() do
      "../.."
    else
      "."
    end
  end

  def get_mix_parent_dirs do
    if in_umbrella?() do
      ["../..", "."]
    else
      ["."]
    end
  end

  def get_mix_child_dirs do
    ["."] ++ if umbrella?(), do: Map.values(Mix.Project.apps_paths()), else: []
  end

  def umbrella? do
    Mix.Project.umbrella?()
  end

  def in_umbrella? do
    apps = Path.dirname(File.cwd!())

    try do
      Mix.Project.in_project(:umbrella_check, "../..", fn _ ->
        path = Mix.Project.config()[:apps_path]
        path && Path.expand(path) == apps
      end)
    catch
      _, _ -> false
    end
  end
end
