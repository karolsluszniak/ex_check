defmodule ExCheck.UmbrellaProjectCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import ExCheck.CaseHelpers
      import ExCheck.UmbrellaProjectCase

      @moduletag timeout: 5 * 60 * 1_000

      setup do
        tmp_dir = create_tmp_directory()
        project_dir = create_mix_project(tmp_dir, umbrella: true)
        apps_dir = Path.join(project_dir, "apps")
        child_a_dir = create_mix_project(apps_dir, name: "child_a")
        child_b_dir = create_mix_project(apps_dir, name: "child_b")
        project_dirs = [project_dir, child_a_dir, child_b_dir]

        set_mix_deps(project_dirs, [:ex_check])
        write_default_config(project_dir)
        on_exit(fn -> remove_tmp_directory(tmp_dir) end)

        {:ok, project_dirs: project_dirs}
      end
    end
  end

  def create_mix_project(root_dir, opts \\ []) do
    name = Keyword.get(opts, :name, "test_project")
    umbrella = Keyword.get(opts, :umbrella, false)
    args = if umbrella, do: ["--umbrella"], else: []

    System.cmd("mix", ["new", name] ++ args, cd: root_dir)

    Path.join(root_dir, name)
  end
end
