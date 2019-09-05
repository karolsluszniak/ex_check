defmodule ExCheck.UmbrellaProjectCases.BaseTest do
  use ExCheck.UmbrellaProjectCase, async: true

  test "base", %{project_dirs: [project_root_dir | _]} do
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_root_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    refute String.contains?(output, "ex_unit success")
    assert String.contains?(output, "ex_unit in child_a success")
    assert String.contains?(output, "ex_unit in child_b success")
    assert String.contains?(output, "credo skipped due to missing package credo")
    refute String.contains?(output, "sobelow skipped due to missing package sobelow")
    assert String.contains?(output, "sobelow in child_a skipped due to missing package sobelow")
    assert String.contains?(output, "sobelow in child_b skipped due to missing package sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing package dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing package ex_doc")

    assert String.contains?(output, "Randomized with seed")
  end
end
