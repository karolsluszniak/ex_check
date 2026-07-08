defmodule ExCheck.ProjectCases.FormatJunitTest do
  use ExCheck.ProjectCase, async: true

  test "junit format writes a JUnit XML report to a file", %{project_dir: project_dir} do
    project_dir |> Path.join("lib") |> Path.join("invalid.ex") |> File.write!("IO.inspect( 1 )")

    System.cmd("mix", ~w[check --format junit --output report.xml], cd: project_dir)
    |> cmd_exit(1)

    xml = project_dir |> Path.join("report.xml") |> File.read!()

    assert String.starts_with?(xml, "<?xml")
    assert xml =~ "<testsuite name=\"mix check\""
    assert xml =~ "<failure"
    assert xml =~ ~s(name="formatter")
  end
end
