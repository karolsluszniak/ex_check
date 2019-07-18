defmodule ExCheckTest do
  use ExUnit.Case

  test "default checks on new project" do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    tmp_dir = "/tmp/ex_check_test-#{timestamp}"
    proj_dir = tmp_dir <> "/test_proj"

    File.mkdir!(tmp_dir)

    cmd(tmp_dir, ~w(mix new test_proj))
    add_self_dep(proj_dir)
    cmd(proj_dir, ~w(mix deps.get))

    assert {output, 0} = System.cmd("mix", ~w[check], cd: proj_dir)

    assert String.contains?(output, "compiler success")
    assert String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    assert String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "sobelow skipped due to missing dependency sobelow")
    assert String.contains?(output, "dialyzer skipped due to missing dependency dialyxir")
    assert String.contains?(output, "ex_doc skipped due to missing dependency ex_doc")
  end

  defp cmd(dir, [app | args]) do
    System.cmd(app, args, cd: dir)
  end

  defp add_self_dep(proj_dir) do
    config_path = "#{proj_dir}/mix.exs"
    deps_from = ~r/ *defp deps.*end\n/Us

    deps_to = """
      defp deps do
        [
          {:ex_check, path: "#{File.cwd!()}"}
        ]
      end
    """

    new_config =
      config_path
      |> File.read!()
      |> String.replace(deps_from, deps_to)

    unless String.contains?(new_config, "ex_check"), do: raise("unable to add ex_check dep")

    File.write!(config_path, new_config)
  end
end
