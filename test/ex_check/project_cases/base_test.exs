defmodule ExCheck.ProjectCases.BaseTest do
  use ExCheck.ProjectCase, async: true

  test "base", %{project_dir: project_dir} do
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo skipped due to missing package credo")
    assert String.contains?(output, "sobelow skipped due to missing package sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing package dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing package ex_doc")
    refute String.contains?(output, "npm_test")

    assert String.contains?(output, "Randomized with seed")
  end
end
