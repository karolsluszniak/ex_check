defmodule ExCheck.Project do
  @moduledoc false

  def has_dep?(name) do
    Mix.Project.config()
    |> Keyword.fetch!(:deps)
    |> List.keymember?(name, 0)
  end

  def get_root_dir do
    "."
  end

  def get_root_and_app_dirs do
    [get_root_dir()] ++ if umbrella?(), do: Map.values(Mix.Project.apps_paths()), else: []
  end

  def umbrella? do
    Mix.Project.umbrella?()
  end
end
