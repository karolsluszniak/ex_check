defmodule ExCheck.ProjectCases.ExternalToolsTest do
  use ExCheck.ProjectCase, async: true

  test "external tools (except dialyzer)", %{project_dir: project_dir} do
    tools =
      if Version.match?(System.version(), "< 1.10.0") do
        [:ex_check, :credo, :doctor, :sobelow, :mix_audit]
      else
        [:ex_check, :credo, :doctor, :ex_doc, :sobelow, :mix_audit]
      end

    set_mix_deps(project_dir, tools)

    assert {output, 0} =
             System.cmd("mix", ~w[check], cd: project_dir, env: %{"MIX_ENV" => "dev"})

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit success"
    assert output =~ "credo success"

    if Version.match?(System.version(), ">= 1.8.0") do
      assert output =~ "doctor success"
    else
      assert output =~ "doctor skipped"
    end

    if Version.match?(System.version(), ">= 1.10.0") do
      assert output =~ "ex_doc success"
    else
      assert output =~ "ex_doc skipped due to missing package ex_doc"
    end

    assert output =~ "sobelow success"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "mix_audit success"
  end
end
