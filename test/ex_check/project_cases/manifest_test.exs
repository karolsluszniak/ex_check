defmodule ExCheck.ProjectCases.ManifestTest do
  use ExCheck.ProjectCase, async: true

  test "formatter issue", %{project_dir: project_dir} do
    invalid_file_path =
      project_dir
      |> Path.join("lib")
      |> Path.join("invalid.ex")

    File.write!(invalid_file_path, "IO.inspect( 1 )")

    assert {output, 1} = System.cmd("mix", ~w[check --manifest manifest.txt], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter error code 1"
    assert output =~ "ex_unit success"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"

    manifest = File.read!(Path.join(project_dir, "manifest.txt"))

    expected_manifest =
      """
      PASS compiler
      PASS unused_deps
      FAIL formatter
      PASS ex_unit
      SKIP credo
      SKIP doctor
      SKIP sobelow
      SKIP ex_doc
      SKIP mix_audit
      SKIP dialyzer
      """
      |> String.split("\n")
      |> Enum.sort()

    expected_manifest =
      if Version.match?(System.version(), ">= 1.10.0") do
        expected_manifest
      else
        (expected_manifest -- ["PASS unused_deps"]) ++ ["SKIP unused_deps"]
      end

    assert manifest |> String.split("\n") |> Enum.sort() == expected_manifest

    assert {output, 1} = System.cmd("mix", ~w[check --manifest manifest.txt], cd: project_dir)

    assert output =~ "retrying automatically"
    assert output =~ "compiler success"
    assert output =~ "formatter error code 1"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "mix_audit skipped due to missing package mix_audit"

    assert {output, 1} =
             System.cmd("mix", ~w[check --manifest manifest.txt --retry], cd: project_dir)

    refute output =~ "retrying automatically"
    assert output =~ "compiler success"
    assert output =~ "formatter error code 1"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "mix_audit skipped due to missing package mix_audit"

    assert {output, 1} =
             System.cmd("mix", ~w[check --manifest manifest.txt --no-retry], cd: project_dir)

    refute output =~ "retrying automatically"
    assert output =~ "compiler success"
    assert output =~ "formatter error code 1"
    assert output =~ "ex_unit success"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"
    assert output =~ "mix_audit skipped due to missing package mix_audit"

    assert {output, 0} =
             System.cmd("mix", ~w[check --manifest manifest.txt --retry --fix], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter fix success"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "mix_audit skipped due to missing package mix_audit"

    assert {output, 0} =
             System.cmd("mix", ~w[check --manifest manifest.txt --retry], cd: project_dir)

    assert output =~ "compiler success"
    refute output =~ "formatter success"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "mix_audit skipped due to missing package mix_audit"

    failing_test_path =
      project_dir
      |> Path.join("test")
      |> Path.join("failing_test.exs")

    File.write!(failing_test_path, """
    defmodule TestProjectFailingTest do
      use ExUnit.Case

      test "sample failure" do
        assert TestProject.hello() == :universe
      end
    end
    """)

    assert {output, 1} =
             System.cmd("mix", ~w[check --only ex_unit --only formatter], cd: project_dir)

    assert output =~ "formatter success"
    assert output =~ "ex_unit error code"
    assert output =~ "2 tests, 1 failure"

    assert {output, 1} = System.cmd("mix", ~w[check --retry], cd: project_dir)

    refute output =~ "formatter"
    assert output =~ "ex_unit error code 1"
    assert output =~ "1 test, 1 failure"

    File.write!(
      failing_test_path,
      File.read!(failing_test_path) |> String.replace(":universe", ":world")
    )

    assert {output, 0} = System.cmd("mix", ~w[check --retry], cd: project_dir)

    refute output =~ "formatter"
    assert output =~ "ex_unit retry success"
  end
end
