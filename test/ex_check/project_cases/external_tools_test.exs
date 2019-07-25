defmodule ExCheck.ProjectCases.ExternalToolsTest do
  use ExCheck.ProjectCase, async: true

  test "external tools (except dialyzer)", %{project_dir: project_dir} do
    set_mix_deps(project_dir, [:ex_check, :credo, :ex_doc, :sobelow])

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir, env: %{"MIX_ENV" => "dev"})

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo success")
    assert String.contains?(output, "sobelow success")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc success")
  end
end
