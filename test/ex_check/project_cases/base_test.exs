defmodule ExCheck.ProjectCases.BaseTest do
  use ExCheck.ProjectCase, async: true

  test "base", %{project_dir: project_dir} do
    output = System.cmd("mix", ~w[check], cd: project_dir) |> cmd_exit(0)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit success"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "npm_test"
    assert output =~ "unused_deps success"
    assert output =~ "Randomized with seed"
  end
end
