defmodule ExCheck.Reporter.AgentTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias ExCheck.Reporter.Agent

  defp results do
    [
      {:ok, {:compiler, ["mix", "compile"], []}, {0, "", 2}},
      {:error, {:formatter, ["mix", "format", "--check-formatted"], []},
       {1, "\e[31m** (Mix) not formatted\e[0m\nlib/foo.ex\n", 1}},
      {:skipped, :credo, {:package, "credo"}}
    ]
  end

  defp report(results, duration \\ 15) do
    capture_io(fn -> Agent.report(results, duration, []) end)
  end

  defp header_line(output) do
    output
    |> String.split("\n")
    |> Enum.find(&String.starts_with?(&1, "{"))
    |> Jason.decode!()
  end

  test "wraps the report in stable delimiters" do
    output = report(results())
    assert output =~ "<<<EX_CHECK_REPORT>>>"
    assert output =~ "<<<END_EX_CHECK_REPORT>>>"
  end

  test "header is machine-readable with the failed verdict" do
    header = header_line(report(results()))

    assert header["status"] == "error"
    assert header["passed"] == 1
    assert header["failed"] == 1
    assert header["skipped"] == 1
    assert header["failed_checks"] == ["formatter"]
  end

  test "emits a raw, unescaped, ANSI-stripped block per failed check" do
    output = report(results())

    assert output =~ "=== FAILED: formatter — mix format --check-formatted (exit 1) ==="
    assert output =~ "** (Mix) not formatted\nlib/foo.ex"
    refute output =~ "\e["
  end

  test "success run is just the delimited header, no failure blocks" do
    output = report([{:ok, {:compiler, ["mix", "compile"], []}, {0, "", 2}}])
    header = header_line(output)

    assert header["status"] == "ok"
    assert header["failed_checks"] == []
    refute output =~ "=== FAILED:"
  end

  test "renders umbrella app in failed_checks" do
    results = [
      {:error, {{:formatter, :child_app}, ["mix", "format"], []}, {1, "bad\n", 1}}
    ]

    assert header_line(report(results))["failed_checks"] == ["formatter in child_app"]
  end
end
