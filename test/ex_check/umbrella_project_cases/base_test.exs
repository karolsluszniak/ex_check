defmodule ExCheck.UmbrellaProjectCases.BaseTest do
  use ExCheck.UmbrellaProjectCase, async: true

  test "base", %{project_dirs: [project_root_dir | _]} do
    System.cmd("mix", ~w[compile], cd: project_root_dir) |> cmd_exit(0)

    # Prebuild the shared _build/test so parallel ex_unit runs in child apps don't race
    # compiling the same deps.
    System.cmd("mix", ~w[compile], cd: project_root_dir, env: %{"MIX_ENV" => "test"})
    |> cmd_exit(0)

    output = System.cmd("mix", ~w[check], cd: project_root_dir) |> cmd_exit(0)

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

    assert output =~ "Randomized with seed" or
             output =~ "Running ExUnit with seed"
  end
end
