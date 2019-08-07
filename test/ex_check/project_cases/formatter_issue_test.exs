defmodule ExCheck.ProjectCases.FormatterIssueTest do
  use ExCheck.ProjectCase, async: true

  test "formatter issue", %{project_dir: project_dir} do
    invalid_file_path =
      project_dir
      |> Path.join("lib")
      |> Path.join("invalid.ex")

    File.write!(invalid_file_path, "IO.inspect( 1 )")

    assert {output, 1} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter error code 1")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo skipped due to missing package credo")
    assert String.contains?(output, "sobelow skipped due to missing package sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing package dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing package ex_doc")

    assert String.contains?(output, """
           ** (Mix) mix format failed due to --check-formatted.
           The following files were not formatted:
           """)
  end
end
