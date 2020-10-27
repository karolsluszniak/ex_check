defmodule ExCheck.ProjectCases.BaseTest do
  use ExCheck.ProjectCase, async: true

  test "base", %{project_dir: project_dir} do
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit success"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"
    refute output =~ "npm_test"

    if Version.match?(System.version(), ">= 1.10.0") do
      assert output =~ "unused_deps success"
    else
      assert output =~ "unused_deps skipped due to Elixir version ="
    end

    assert output =~ "Randomized with seed"
  end
end
