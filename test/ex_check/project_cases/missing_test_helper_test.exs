defmodule ExCheck.ProjectCases.MissingTestHelperTest do
  use ExCheck.ProjectCase, async: true

  test "missing test directory", %{project_dir: project_dir} do
    test_dir_path = Path.join(project_dir, "test")
    File.rm_rf!(test_dir_path)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit skipped due to missing file test")
    assert String.contains?(output, "credo skipped due to missing package credo")
    assert String.contains?(output, "sobelow skipped due to missing package sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing package dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing package ex_doc")
  end
end
