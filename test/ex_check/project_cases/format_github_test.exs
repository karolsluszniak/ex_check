defmodule ExCheck.ProjectCases.FormatGithubTest do
  use ExCheck.ProjectCase, async: true

  test "github format emits log groups and writes a step summary", %{project_dir: project_dir} do
    project_dir |> Path.join("lib") |> Path.join("invalid.ex") |> File.write!("IO.inspect( 1 )")
    summary_path = Path.join(project_dir, "step_summary.md")

    output =
      System.cmd("mix", ~w[check --format github],
        cd: project_dir,
        env: [{"GITHUB_STEP_SUMMARY", summary_path}]
      )
      |> cmd_exit(1)

    assert output =~ "::group::"
    assert output =~ "::endgroup::"
    assert output =~ "::error::mix check failed:"

    summary = File.read!(summary_path)
    assert summary =~ "## mix check"
    assert summary =~ "| Check | Status | Duration |"
    assert summary =~ "❌"
  end

  test "--output is rejected for the github format", %{project_dir: project_dir} do
    {output, code} =
      System.cmd("mix", ~w[check --format github --output report.txt],
        cd: project_dir,
        stderr_to_stdout: true
      )

    assert code != 0
    assert output =~ "--output requires"
  end
end
