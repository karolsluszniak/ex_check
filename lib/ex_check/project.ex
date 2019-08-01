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
