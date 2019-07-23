defmodule ExCheck.Check do
  @moduledoc false

  alias ExCheck.{Command, Config, Printer, Project}

  def run(opts) do
    config = Config.load()
    tools_from_config = Config.get_tools(config)
    opts_from_config = Config.get_opts(config)
    opts_merged = Keyword.merge(opts_from_config, opts)

    compile_and_run_tools(tools_from_config, opts_merged)
  end

  defp compile_and_run_tools(tools, opts) do
    start_time = DateTime.utc_now()
    compiler_result = run_compiler(tools, opts)
    other_results = if run_others?(compiler_result), do: run_others(tools, opts), else: []
    total_duration = DateTime.diff(DateTime.utc_now(), start_time)

    present_results([compiler_result] ++ other_results, total_duration, opts)
  end

  defp run_compiler(tools, opts) do
    check = List.keyfind(tools, :compiler, 0) || raise("compiler check not found")
    check = prepare_check(check, opts)
    check = with {:disabled, _} <- check, do: {:pending, {:compiler, "mix compile", []}}

    run_check(check)
  end

  @compile_warn_out "Compilation failed due to warnings while using the --warnings-as-errors option"

  defp run_others?(_compiler_result = {status, _, {_, output, _}}) do
    status == :ok or String.contains?(output, @compile_warn_out)
  end

  defp run_others(tools, opts) do
    tools =
      tools
      |> List.keydelete(:compiler, 0)
      |> Enum.map(&prepare_check(&1, opts))

    if Keyword.get(opts, :parallel, true) do
      tools
      |> Enum.map(&start_check_task/1)
      |> Enum.map(&await_check_task/1)
    else
      Enum.map(tools, &run_check/1)
    end
  end

  defp prepare_check({name, false}, _opts) do
    {:disabled, name}
  end

  defp prepare_check({name, config}, opts) do
    command = Keyword.fetch!(config, :command)
    command_opts = Keyword.take(config, [:cd, :env])
    require_deps = Keyword.get(config, :require_deps, [])
    require_files = Keyword.get(config, :require_files, [])

    cond do
      Keyword.has_key?(opts, :only) && !Enum.any?(opts, &(&1 == {:only, name})) ->
        {:disabled, name}

      Enum.any?(opts, fn i -> i == {:except, name} end) ->
        {:disabled, name}

      missing_dep = find_missing_dep(require_deps) ->
        {:skipped, name, ["missing dependency ", :bright, to_string(missing_dep), :normal]}

      missing_file = find_missing_file(require_files) ->
        {:skipped, name, ["missing file ", :bright, missing_file, :normal]}

      true ->
        {:pending, {name, command, command_opts}}
    end
  end

  defp find_missing_dep(require_deps) do
    Enum.find(require_deps, &(not Project.has_dep?(&1)))
  end

  defp find_missing_file(require_files) do
    dirs = Project.get_mix_child_dirs()

    Enum.find(require_files, fn file ->
      not Enum.any?(dirs, fn dir ->
        dir
        |> Path.join(file)
        |> File.exists?()
      end)
    end)
  end

  defp run_check(check) do
    check
    |> start_check_task()
    |> await_check_task()
  end

  @ansi_code_regex ~r/(\x1b\[[0-9;]*m)/

  defp start_check_task({:pending, {name, cmd, opts}}) do
    stream = fn out ->
      out
      |> String.replace(@ansi_code_regex, "\\1" <> IO.ANSI.faint())
      |> IO.write()
    end

    {final_cmd, env_from_cmd} = prepare_cmd_and_env(cmd)
    env_from_opts = Keyword.get(opts, :env, %{})
    final_env = Map.merge(env_from_cmd, env_from_opts)
    final_opts = Keyword.merge(opts, stream: stream, silenced: true, env: final_env)
    task = Command.async(final_cmd, final_opts)

    {:running, {name, cmd, opts}, task}
  end

  defp start_check_task(inactive_check) do
    inactive_check
  end

  defp prepare_cmd_and_env(cmd) when is_binary(cmd) do
    cmd
    |> String.split(" ")
    |> prepare_cmd_and_env()
  end

  defp prepare_cmd_and_env(["mix", task | task_args]) do
    task_env = Project.get_task_env(task)

    if Project.check_runner_available?(task_env) do
      {["mix", "check.run", task | task_args], %{"MIX_ENV" => "#{task_env}"}}
    else
      {["mix", task | task_args], %{"MIX_ENV" => "#{task_env}"}}
    end
  end

  defp prepare_cmd_and_env(cmd) do
    {cmd, %{}}
  end

  defp await_check_task({:running, {name, cmd, opts}, task}) do
    Printer.info([:magenta, "=> running ", :bright, to_string(name)])
    Printer.info()
    IO.write(IO.ANSI.faint())

    {output, code, duration} =
      task
      |> Command.unsilence()
      |> Command.await()

    if output_needs_padding?(output), do: Printer.info()
    IO.write(IO.ANSI.reset())

    status = if code == 0, do: :ok, else: :error

    {status, {name, cmd, opts}, {code, output, duration}}
  end

  defp await_check_task(inactive_check) do
    inactive_check
  end

  defp output_needs_padding?(output) do
    not (String.match?(output, ~r/\n{2,}$/) or output == "")
  end

  defp present_results(finished_tools, total_duration, opts) do
    failed_tools = Enum.filter(finished_tools, &match?({:error, _, _}, &1))

    Enum.each(failed_tools, fn {_, {name, _, _}, {_, output, _}} ->
      Printer.info([:red, "=> reprinting errors from ", :bright, to_string(name)])
      Printer.info()
      IO.write(output)
      if output_needs_padding?(output), do: Printer.info()
    end)

    Printer.info([:magenta, "=> finished in ", :bright, format_duration(total_duration)])
    Printer.info()

    Enum.each(finished_tools, fn
      {:ok, {name, _, _}, {_, _, duration}} ->
        took = format_duration(duration)
        name = to_string(name)
        Printer.info([:green, " ✓ ", :bright, name, :normal, " success in ", :bright, took])

      {:error, {name, _, _}, {code, _, duration}} ->
        n = :normal
        b = :bright
        name = to_string(name)
        code_string = to_string(code)
        took = format_duration(duration)

        Printer.info([:red, " ✕ ", b, name, n, " error code ", b, code_string, n, " in ", b, took])

      {:skipped, name, reason} ->
        if Keyword.get(opts, :skipped, true) do
          Printer.info(
            [:cyan, "   ", :bright, to_string(name), :normal, " skipped due to "] ++ reason
          )
        end

      {:disabled, _} ->
        :ok
    end)

    Printer.info()

    if Keyword.get(opts, :exit_status, true) and Enum.any?(failed_tools) do
      System.halt(length(failed_tools))
      Process.sleep(:infinity)
    end
  end

  defp format_duration(secs) do
    min = div(secs, 60)
    sec = rem(secs, 60)
    sec_str = if sec < 10, do: "0#{sec}", else: "#{sec}"

    "#{min}:#{sec_str}"
  end
end
