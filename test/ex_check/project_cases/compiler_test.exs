defmodule ExCheck.ProjectCases.CompilerTest do
  use ExCheck.ProjectCase, async: true

  test "formatter issue", %{project_dir: project_dir} do
    invalid_file_path =
      project_dir
      |> Path.join("lib")
      |> Path.join("invalid.ex")

    File.write!(invalid_file_path, """
    defmodule Invalid do
      def test do
        a = 1

        :ok
      end
    end
    """)

    assert {output, 1} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "compiler error code 1"
    assert output =~ "variable \"a\" is unused"

    assert {output, 0} = System.cmd("mix", ~w[check --except compiler --no-retry], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
  end
end
