defmodule ExCheckTest do
  use ExUnit.Case

  setup do
    project_dir =
      create_tmp_directory()
      |> create_mix_project()

    set_mix_deps(project_dir, [:ex_check])

    on_exit(fn ->
      remove_tmp_directory()
    end)

    {:ok, project_dir: project_dir}
  end

  test "default tools", %{project_dir: project_dir} do
    set_mix_deps(project_dir, [:ex_check])

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "sobelow skipped due to missing dependency sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing dependency ex_doc")

    assert String.contains?(output, "Randomized with seed")
  end

  test "default tools, missing test helper", %{project_dir: project_dir} do
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    test_helper_path =
      project_dir
      |> Path.join("test")
      |> Path.join("test_helper.exs")

    File.rm!(test_helper_path)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "sobelow skipped due to missing dependency sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing dependency ex_doc")
  end

  test "default tools, formatter issue", %{project_dir: project_dir} do
    invalid_file_path =
      project_dir
      |> Path.join("lib")
      |> Path.join("invalid.ex")

    File.write!(invalid_file_path, "IO.inspect( 1 )")

    assert {output, 1} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter error code 1")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "sobelow skipped due to missing dependency sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing dependency ex_doc")

    assert String.contains?(output, """
           ** (Mix) mix format failed due to --check-formatted.
           The following files were not formatted:
           """)
  end

  test "all tools (except dialyzer)", %{project_dir: project_dir} do
    set_mix_deps(project_dir, [:ex_check, :credo, :ex_doc, :sobelow])

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir, env: %{"MIX_ENV" => "dev"})

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo success")
    assert String.contains?(output, "sobelow success")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc success")
  end

  defp create_tmp_directory do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    tmp_dir =
      System.tmp_dir!()
      |> Path.join("ex_check_test")
      |> Path.join("#{timestamp}")

    File.mkdir_p!(tmp_dir)

    tmp_dir
  end

  defp remove_tmp_directory do
    tmp_dir =
      System.tmp_dir!()
      |> Path.join("ex_check_test")

    File.rm_rf!(tmp_dir)
  end

  defp create_mix_project(root_dir) do
    System.cmd("mix", ~w(new test_project), cd: root_dir)

    Path.join(root_dir, "test_project")
  end

  defp set_mix_deps(project_dir, deps) do
    config_path = "#{project_dir}/mix.exs"
    deps_from = ~r/ *defp deps.*end\n/Us

    deps_list =
      Enum.map(deps, fn
        :ex_check ->
          "{:ex_check, path: \"#{File.cwd!()}\"}"

        dep ->
          "{:#{dep}, \">= 0.0.0\", only: :dev, runtime: false}"
      end)

    deps_to = """
      defp deps do
        [
          #{Enum.join(deps_list, ",\n      ")}
        ]
      end
    """

    new_config =
      config_path
      |> File.read!()
      |> String.replace(deps_from, deps_to)

    unless String.contains?(new_config, "ex_check"), do: raise("unable to add ex_check dep")

    File.write!(config_path, new_config)
    {_, 0} = System.cmd("mix", ~w[deps.get], cd: project_dir)

    project_dir
  end
end
