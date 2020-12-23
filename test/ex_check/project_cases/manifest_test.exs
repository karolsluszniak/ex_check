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

    assert manifest == """
           PASS compiler
           FAIL formatter
           PASS ex_unit
           PASS unused_deps
           SKIP credo
           SKIP sobelow
           SKIP ex_doc
           SKIP dialyzer
           """

    assert {output, 1} =
             System.cmd("mix", ~w[check --manifest manifest.txt --failed], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter error code 1"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"

    File.rm!(invalid_file_path)

    assert {output, 0} =
             System.cmd("mix", ~w[check --manifest manifest.txt --failed], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"

    assert {output, 0} =
             System.cmd("mix", ~w[check --manifest manifest.txt --failed], cd: project_dir)

    assert output =~ "compiler success"
    refute output =~ "formatter success"
    refute output =~ "ex_unit success"
    refute output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    refute output =~ "dialyzer skipped due to missing package dialyxir"
    refute output =~ "ex_doc skipped due to missing package ex_doc"
  end
end
