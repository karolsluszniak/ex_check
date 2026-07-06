defmodule ExCheck.ProjectCases.FormatJsonTest do
  use ExCheck.ProjectCase, async: true

  defp report(output) do
    output
    |> String.split("\n")
    |> Enum.find(&String.starts_with?(&1, "{"))
    |> Jason.decode!()
  end

  test "json format to stdout, with a failure", %{project_dir: project_dir} do
    project_dir |> Path.join("lib") |> Path.join("invalid.ex") |> File.write!("IO.inspect( 1 )")

    output = System.cmd("mix", ~w[check --format json], cd: project_dir) |> cmd_exit(1)

    report = report(output)
    assert report["status"] == "error"
    assert report["failed"] >= 1

    formatter = Enum.find(report["checks"], &(&1["name"] == "formatter"))
    assert formatter["status"] == "error"
    assert formatter["exit_code"] == 1
    assert formatter["output"] =~ "format"

    refute output =~ "=> running"
    refute output =~ "✓"
  end

  test "json format to a file leaves stdout clean", %{project_dir: project_dir} do
    project_dir |> Path.join("lib") |> Path.join("invalid.ex") |> File.write!("IO.inspect( 1 )")

    output =
      System.cmd("mix", ~w[check --format json --output report.json], cd: project_dir)
      |> cmd_exit(1)

    refute output =~ ~s("status")

    report = project_dir |> Path.join("report.json") |> File.read!() |> Jason.decode!()
    assert report["status"] == "error"
    assert Enum.any?(report["checks"], &(&1["name"] == "formatter" and &1["status"] == "error"))
  end

  test "compiler check exposes parsed diagnostics", %{project_dir: project_dir} do
    # unused variable -> compiler warning -> failure under --warnings-as-errors
    project_dir
    |> Path.join("lib")
    |> Path.join("warn.ex")
    |> File.write!("defmodule Warn do\n  def f do\n    x = 1\n    :ok\n  end\nend\n")

    output = System.cmd("mix", ~w[check --format json], cd: project_dir) |> cmd_exit(1)
    report = report(output)

    compiler = Enum.find(report["checks"], &(&1["name"] == "compiler"))
    assert compiler["status"] == "error"
    assert [diag | _] = compiler["diagnostics"]
    assert diag["file"] =~ "warn.ex"
    assert is_integer(diag["line"])
  end

  test "--output without a batch format is rejected", %{project_dir: project_dir} do
    {output, code} =
      System.cmd("mix", ~w[check --output report.json], cd: project_dir, stderr_to_stdout: true)

    assert code != 0
    assert output =~ "--output requires"
  end
end
