defmodule ExCheck.ProjectCases.FormatAgentTest do
  use ExCheck.ProjectCase, async: true

  defp header(output) do
    output
    |> String.split("\n")
    |> Enum.find(&String.starts_with?(&1, "{"))
    |> Jason.decode!()
  end

  test "agent format, all passing", %{project_dir: project_dir} do
    output = System.cmd("mix", ~w[check --format agent], cd: project_dir) |> cmd_exit(0)

    assert output =~ "<<<EX_CHECK_REPORT>>>"
    assert output =~ "<<<END_EX_CHECK_REPORT>>>"
    assert header(output)["status"] == "ok"
    assert header(output)["failed_checks"] == []

    refute output =~ "=> running"
    refute output =~ "✓"
    refute output =~ "=> reprinting errors"
    refute output =~ "=== FAILED:"
  end

  test "agent format, with a failure", %{project_dir: project_dir} do
    project_dir |> Path.join("lib") |> Path.join("invalid.ex") |> File.write!("IO.inspect( 1 )")

    output =
      System.cmd("mix", ~w[check --format agent --manifest manifest.txt], cd: project_dir)
      |> cmd_exit(1)

    header = header(output)
    assert header["status"] == "error"
    assert "formatter" in header["failed_checks"]

    assert output =~ "=== FAILED: formatter"
    refute output =~ "=> running"

    assert File.exists?(Path.join(project_dir, "manifest.txt"))
  end
end
