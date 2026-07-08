defmodule ExCheck.Reporter.JunitTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias ExCheck.Reporter.Junit

  defp results do
    [
      {:ok, {:compiler, ["mix", "compile"], []}, {0, "", 2}},
      {:error, {:formatter, ["mix", "format", "--check-formatted"], []},
       {1, "\e[31m** (Mix) not formatted\e[0m\nlib/foo.ex <tag> & more\n", 1}},
      {:ok, {{:ex_unit, :child_app}, ["mix", "test"], []}, {0, "", 3}},
      {:skipped, :credo, {:package, "credo"}}
    ]
  end

  defp build(results \\ results(), duration \\ 15),
    do: IO.iodata_to_binary(Junit.build(results, duration))

  test "emits a testsuite with counts and total time" do
    xml = build()

    assert xml =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
    assert xml =~ ~s(<testsuite name="mix check" tests="4" failures="1" skipped="1" time="15">)
  end

  test "ok testcase is self-closing with its duration" do
    assert build() =~ ~s(<testcase classname="check" name="compiler" time="2"/>)
  end

  test "failure testcase carries stripped, escaped output" do
    xml = build()

    assert xml =~ ~s(<testcase classname="check" name="formatter" time="1">)
    assert xml =~ ~s(<failure message="exit code 1">)
    assert xml =~ "** (Mix) not formatted\nlib/foo.ex &lt;tag&gt; &amp; more"
    refute xml =~ "\e["
  end

  test "umbrella app becomes classname suffix" do
    assert build() =~ ~s(<testcase classname="check.child_app" name="ex_unit" time="3"/>)
  end

  test "skipped testcase carries its reason" do
    xml = build()

    assert xml =~ ~s(<testcase classname="check" name="credo" time="0">)
    assert xml =~ ~s(<skipped message="missing package credo"/>)
  end

  test "report/3 writes to stdout" do
    out = capture_io(fn -> Junit.report(results(), 15, []) end)
    assert out =~ "<testsuites>"
  end

  test "report/3 writes to a file when :output set" do
    path = Path.join(System.tmp_dir!(), "ex_check_junit_#{System.unique_integer([:positive])}.xml")
    on_exit(fn -> File.rm(path) end)

    assert capture_io(fn -> Junit.report(results(), 15, output: path) end) == ""
    assert path |> File.read!() |> String.starts_with?(~s(<?xml))
  end
end
