defmodule ExCheck.Command do
  @moduledoc false

  def run(command, opts \\ []) do
    command
    |> async(opts)
    |> await()
  end

  def async([exec | args], opts) do
    stream_fn = parse_stream_option(opts)
    cd = Keyword.get(opts, :cd, ".")
    exec_path = resolve_exec_path(exec, cd)

    env =
      opts
      |> Keyword.get(:env, %{})
      |> Enum.map(fn {n, v} -> {String.to_charlist(n), String.to_charlist(v)} end)

    spawn_opts = [
      :stream,
      :binary,
      :exit_status,
      :hide,
      :use_stdio,
      :stderr_to_stdout,
      args: args,
      cd: cd,
      env: env
    ]

    Task.async(fn ->
      start_time = DateTime.utc_now()
      port = Port.open({:spawn_executable, exec_path}, spawn_opts)
      handle_port(port, stream_fn, "", "", opts[:silenced], start_time)
    end)
  end

  def unsilence(task = %Task{pid: pid}) do
    send(pid, :unsilence)
    task
  end

  def await(task, timeout \\ :infinity) do
    {output, status, stream_fn, silenced, duration} = Task.await(task, timeout)
    if silenced, do: stream_fn.(output)
    {output, status, duration}
  end

  @ansi_code_regex ~r/(\x1b\[[0-9;]*m)/

  defp parse_stream_option(opts) do
    case Keyword.get(opts, :stream) do
      true ->
        if Keyword.get(opts, :tint) && IO.ANSI.enabled?() do
          fn output ->
            output
            |> String.replace(@ansi_code_regex, "\\1" <> IO.ANSI.faint())
            |> IO.write()
          end
        else
          &IO.write/1
        end

      falsy when falsy in [nil, false] ->
        fn _ -> nil end

      func when is_function(func) ->
        func
    end
  end

  defp resolve_exec_path(exec, cd) do
    cond do
      Path.type(exec) == :absolute -> exec
      File.exists?(Path.join(cd, exec)) -> Path.join(cd, exec) |> Path.expand()
      path_to_exec = System.find_executable(exec) -> path_to_exec
      true -> raise("executable not found: #{exec}")
    end
  end

  defp handle_port(port, stream_fn, out, trail_ws, silenced, start_time) do
    receive do
      {^port, {:data, new_out}} ->
        new_out = trim_lead_ws(new_out, out)
        {new_out, new_trail_ws} = split_trail_ws(new_out)
        {new_out, trail_ws} = drain_prev_trail_ws(new_out, trail_ws)

        unless silenced, do: stream_fn.(new_out)

        handle_port(port, stream_fn, out <> new_out, trail_ws <> new_trail_ws, silenced, start_time)

      {^port, {:exit_status, status}} ->
        duration = DateTime.diff(DateTime.utc_now(), start_time)

        {out, status, stream_fn, silenced, duration}

      :unsilence ->
        stream_fn.(out)

        handle_port(port, stream_fn, out, trail_ws, false, start_time)
    end
  end

  defp trim_lead_ws(new_out, ""), do: String.replace(new_out, ~r/^\s*/, "")
  defp trim_lead_ws(new_out, _), do: new_out

  @trail_ws_regex ~r/(?<out>.*?)(?<trail_ws>(\s|\x1b\[[0-9;]*m)*)$/s

  defp split_trail_ws(new_out) do
    [[new_out, new_trail_ws] | _] = Regex.scan(@trail_ws_regex, new_out, capture: :all_names)
    {new_out, new_trail_ws}
  end

  defp drain_prev_trail_ws(new_out = "", trail_ws), do: {new_out, trail_ws}
  defp drain_prev_trail_ws(new_out, trail_ws = ""), do: {new_out, trail_ws}
  defp drain_prev_trail_ws(new_out, trail_ws), do: {trail_ws <> new_out, ""}
end
