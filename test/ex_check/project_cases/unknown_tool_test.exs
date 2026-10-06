defmodule ExCheck.ProjectCases.UnknownToolTest do
  use ExCheck.ProjectCase, async: true

  test "disabling an unknown tool", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, "[tools: [{:foo, false}]]")

    output = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true) |> cmd_exit(1)

    assert output =~ "cannot disable unknown tool :foo: it is not defined and has no :command"
    refute output =~ "KeyError"
    refute output =~ "key :command not found"
  end

  test "disabling an unknown tool with enabled: false", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, "[tools: [{:foo, enabled: false}]]")

    output = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true) |> cmd_exit(1)

    assert output =~ "cannot disable unknown tool :foo: it is not defined and has no :command"
    refute output =~ "KeyError"
    refute output =~ "key :command not found"
  end

  test "disabling a custom tool that defines a command", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, ~s/[tools: [{:my_tool, command: "echo ok", enabled: false}]]/)

    output = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true) |> cmd_exit(0)

    refute output =~ "my_tool"
    refute output =~ "KeyError"
  end
end
