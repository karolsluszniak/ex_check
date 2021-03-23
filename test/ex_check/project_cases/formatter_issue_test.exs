defmodule ExCheck.ProjectCases.FormatterIssueTest do
  use ExCheck.ProjectCase, async: true

  test "formatter issue", %{project_dir: project_dir} do
    invalid_file_path =
      project_dir
      |> Path.join("lib")
      |> Path.join("invalid.ex")

    File.write!(invalid_file_path, "IO.inspect( 1 )")

    assert {output, 1} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter error code 1"
    assert output =~ "ex_unit success"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"

    assert String.contains?(output, "** (Mix) mix format failed due to --check-formatted.")
  end
end
