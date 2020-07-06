defmodule ExCheck.ProjectCases.GenConfigTest do
  use ExCheck.ProjectCase, async: true

  test "gen config", %{project_dir: project_dir} do
    assert {output, 0} = System.cmd("mix", ~w[check.gen.config], cd: project_dir)

    assert output =~ "creating .check.exs"

    assert {output, 0} = System.cmd("mix", ~w[check.gen.config], cd: project_dir)

    assert output =~ ".check.exs already exists, skipped"

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit success"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "npm_test"

    assert output =~ "Randomized with seed"
  end
end
