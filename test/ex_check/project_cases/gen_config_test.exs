defmodule ExCheck.ProjectCases.GenConfigTest do
  use ExCheck.ProjectCase, async: true

  test "gen config", %{project_dir: project_dir} do
    File.rm!(Path.join(project_dir, ".check.exs"))

    output = System.cmd("mix", ~w[check.gen.config], cd: project_dir) |> cmd_exit(0)

    assert output =~ "creating .check.exs"

    output = System.cmd("mix", ~w[check.gen.config], cd: project_dir) |> cmd_exit(0)

    assert output =~ ".check.exs already exists, skipped"

    output = System.cmd("mix", ~w[check --no-fix], cd: project_dir) |> cmd_exit(0)

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
