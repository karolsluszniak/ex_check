defmodule ExCheck.Project do
  @moduledoc false

  def config do
    Mix.Project.config()
  end

  def apps_paths do
    Mix.Project.apps_paths()
  end

  def has_dep?(name) do
    config()
    |> Keyword.fetch!(:deps)
    |> List.keymember?(name, 0)
  end

  def has_dep_in_app?(name, app) do
    app_path = Map.fetch!(apps_paths(), app)

    Mix.Project.in_project(app, app_path, fn _ ->
      has_dep?(name)
    end)
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
      [Path.join("..", ".."), "."]
    else
      ["."]
    end
  end

  def umbrella? do
    Mix.Project.umbrella?()
  end

  def in_umbrella? do
    apps = Path.dirname(File.cwd!())

    try do
      Mix.Project.in_project(:umbrella_check, "../..", fn _ ->
        path = Mix.Project.config()[:apps_path]
        (path && Path.expand(path) == apps) || false
      end)
    catch
      _, _ -> false
    end
  end
end
