defmodule ExCheck.ProjectCases.ApplicationModTest do
  use ExCheck.ProjectCase, async: true

  @application """
  defmodule TestProject.Application do
    use Application

    def start(_type, _args) do
      children = []

      opts = [strategy: :one_for_one, name: ExCheck.Supervisor]

      if Mix.env() == :test do
        Application.put_env(:test_project, :app_started, true, persistent: true)
      else
        raise("running app!")
      end

      Supervisor.start_link(children, opts)
    end

    def do_sth_with_running_app do
      unless Application.get_env(:test_project, :app_started), do: raise("not running app!")

      :ok
    end
  end
  """

  @application_test """
  defmodule TestProject.ApplicationTest do
    use ExUnit.Case

    test "app running" do
      assert :ok = TestProject.Application.do_sth_with_running_app()
    end
  end
  """

  test "application mod", %{project_dir: project_dir} do
    set_mix_app_mod(project_dir, "TestProject.Application")

    application_path = Path.join([project_dir, "lib", "application.ex"])
    File.write!(application_path, @application)

    application_test_path = Path.join([project_dir, "test", "application_test.exs"])
    File.write!(application_test_path, @application_test)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
  end
end
