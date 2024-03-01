defmodule ExCheck.ProjectCases.ExternalToolsTest do
  use ExCheck.ProjectCase, async: true

  test "external tools (except dialyzer)", %{project_dir: project_dir} do
    tools = [:ex_check, :credo, :doctor, :ex_doc, :gettext, :sobelow, :mix_audit]
    set_mix_deps(project_dir, tools)

    System.cmd("mix", ~w[compile], cd: project_dir, env: %{"MIX_ENV" => "dev"}) |> cmd_exit(0)

    output =
      System.cmd("mix", ~w[check], cd: project_dir, env: %{"MIX_ENV" => "dev"}) |> cmd_exit(0)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit success"
    assert output =~ "credo success"
    assert output =~ "gettext success"
    assert output =~ "doctor success"
    assert output =~ "ex_doc success"
    assert output =~ "sobelow success"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "mix_audit success"
  end
end
