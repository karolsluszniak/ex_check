defmodule ExCheck.Reporter.JsonTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias ExCheck.Reporter.Json

  defp results do
    [
      {:ok, {:compiler, ["mix", "compile"], []}, {0, "", 2}},
      {:error, {:formatter, ["mix", "format", "--check-formatted"], []},
       {1, "\e[31m** (Mix) not formatted\e[0m\nlib/foo.ex\n", 1}},
      {:ok, {{:ex_unit, :child_app}, ["mix", "test"], []}, {0, "", 3}},
      {:skipped, :credo, {:package, "credo"}}
    ]
  end

  test "build/2 produces the summary structure" do
    summary = Json.build(results(), 15)

    assert summary.status == "error"
    assert summary.passed == 2
    assert summary.failed == 1
    assert summary.skipped == 1
    assert summary.duration_s == 15
    assert length(summary.checks) == 4
  end

  test "error check carries stripped output, ok check does not" do
    summary = Json.build(results(), 15)
    by_name = Map.new(summary.checks, &{&1.name, &1})

    formatter = by_name["formatter"]
    assert formatter.status == "error"
    assert formatter.exit_code == 1
    assert formatter.command == "mix format --check-formatted"
    assert formatter.output == "** (Mix) not formatted\nlib/foo.ex\n"
    refute formatter.output =~ "\e["

    refute Map.has_key?(by_name["compiler"], :output)
  end

  test "error check without a parser carries an empty diagnostics list" do
    summary = Json.build(results(), 15)
    by_name = Map.new(summary.checks, &{&1.name, &1})

    assert by_name["formatter"].diagnostics == []
  end

  test "compiler error carries parsed diagnostics" do
    compiler_output =
      "    warning: variable \"x\" is unused\n    │\n    └─ lib/foo.ex:5:11: Foo.bar/1\n"

    results = [{:error, {:compiler, ["mix", "compile"], []}, {1, compiler_output, 2}}]
    summary = Json.build(results, 5)
    [check] = summary.checks

    assert [diag] = check.diagnostics
    assert diag.file == "lib/foo.ex"
    assert diag.line == 5
    assert diag.column == 11
    assert diag.severity == "warning"
    assert diag.message == "variable \"x\" is unused"
  end

  test "umbrella name split and skipped reason" do
    summary = Json.build(results(), 15)
    by_name = Map.new(summary.checks, &{&1.name, &1})

    assert by_name["ex_unit"].app == "child_app"
    assert by_name["compiler"].app == nil
    assert by_name["credo"].status == "skipped"
    assert by_name["credo"].reason == "missing package credo"
  end

  test "report/3 emits a single valid JSON object" do
    output = capture_io(fn -> Json.report(results(), 15, []) end)
    decoded = Jason.decode!(output)

    assert decoded["status"] == "error"
    assert decoded["failed"] == 1
  end

  test "report/3 writes to file when :output set" do
    path = Path.join(System.tmp_dir!(), "ex_check_json_#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(path) end)

    assert capture_io(fn -> Json.report(results(), 15, output: path) end) == ""
    assert path |> File.read!() |> Jason.decode!() |> Map.fetch!("status") == "error"
  end
end
