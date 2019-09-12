defmodule ExCheck.ProjectCases.MissingTestHelperTest do
  use ExCheck.ProjectCase, async: true

  test "missing test helper", %{project_dir: project_dir} do
    test_helper_path =
      project_dir
      |> Path.join("test")
      |> Path.join("test_helper.exs")

    File.rm!(test_helper_path)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "compiler success"
    assert output =~ "formatter success"
    assert output =~ "ex_unit skipped due to missing file test/test_helper.exs"
    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "sobelow skipped due to missing package sobelow"
    assert output =~ "dialyzer skipped due to missing package dialyxir"
    assert output =~ "ex_doc skipped due to missing package ex_doc"
  end
end
