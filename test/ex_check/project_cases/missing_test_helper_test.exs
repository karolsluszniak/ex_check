defmodule ExCheck.ProjectCases.MissingTestHelperTest do
  use ExCheck.ProjectCase, async: true

  test "missing test helper", %{project_dir: project_dir} do
    test_helper_path =
      project_dir
      |> Path.join("test")
      |> Path.join("test_helper.exs")

    File.rm!(test_helper_path)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit skipped due to missing file test/test_helper.exs")
    assert String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "sobelow skipped due to missing dependency sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing dependency ex_doc")
  end
end
