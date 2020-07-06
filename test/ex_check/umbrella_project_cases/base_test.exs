defmodule ExCheck.UmbrellaProjectCases.BaseTest do
  use ExCheck.UmbrellaProjectCase, async: true

  test "base", %{project_dirs: [project_root_dir | _]} do
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_root_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    refute output =~ "ex_unit success"
    assert output =~ "ex_unit in child_a success"
    assert output =~ "ex_unit in child_b success"
    assert output =~ "credo skipped due to missing package credo"
    refute output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "sobelow in child_a skipped due to missing package sobelow"
    assert output =~ "sobelow in child_b skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"

    assert output =~ "Randomized with seed"
  end
end
