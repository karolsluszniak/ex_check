defmodule ExCheck.ProjectCases.UnknownToolTest do
  use ExCheck.ProjectCase, async: true

  test "disabling an unknown tool", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, "[tools: [{:foo, false}]]")

    output = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true) |> cmd_exit(0)

    assert output =~ "warning: ignoring unknown disabled tool :foo"
    refute output =~ "KeyError"
  end

  test "configuring an unknown tool without a command", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, ~s/[tools: [{:foo, cd: "assets"}]]/)

    output = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true) |> cmd_exit(1)

    assert output =~ "unknown tool :foo has no :command"
    refute output =~ "KeyError"
  end

  test "disabling a custom tool that defines a command", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, ~s/[tools: [{:my_tool, command: "echo ok", enabled: false}]]/)

    output = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true) |> cmd_exit(0)

    refute output =~ "my_tool"
    refute output =~ "KeyError"
  end

  test "disabling a tool in --config that the project config defines later", %{
    project_dir: project_dir
  } do
    File.write!(Path.join(project_dir, ".check.exs"), ~s/[tools: [{:my_tool, "false"}]]/)
    File.write!(Path.join(project_dir, "ci.exs"), "[tools: [{:my_tool, false}]]")

    output =
      System.cmd("mix", ~w[check --config ci.exs], cd: project_dir, stderr_to_stdout: true)
      |> cmd_exit(0)

    refute output =~ "my_tool"
  end
end
