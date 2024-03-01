defmodule ExCheck.ProjectCases.MissingTestHelperTest do
  use ExCheck.ProjectCase, async: true

  test "missing test directory", %{project_dir: project_dir} do
    test_dir_path = Path.join(project_dir, "test")
    File.rm_rf!(test_dir_path)

    output = System.cmd("mix", ~w[check], cd: project_dir) |> cmd_exit(0)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit skipped due to missing file test"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"
  end
end
