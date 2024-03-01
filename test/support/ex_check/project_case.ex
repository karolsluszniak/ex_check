defmodule ExCheck.ProjectCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import ExCheck.CaseHelpers
      import ExCheck.ProjectCase

      @moduletag timeout: 5 * 60 * 1_000

      setup do
        tmp_dir = create_tmp_directory()
        project_dir = create_mix_project(tmp_dir)

        set_mix_deps(project_dir, [:ex_check])
        write_default_config(project_dir)
        on_exit(fn -> remove_tmp_directory(tmp_dir) end)

        {:ok, project_dir: project_dir}
      end
    end
  end

  def create_mix_project(root_dir) do
    System.cmd("mix", ~w(new test_project), cd: root_dir)

    Path.join(root_dir, "test_project")
  end
end
