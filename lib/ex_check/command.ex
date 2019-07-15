defmodule ExCheck.Command do
  @moduledoc false

  def run(command, opts \\ []) do
    command
    |> async(opts)
    |> await()
  end

  def async(command, opts \\ [])

  def async(command, opts) when is_binary(command), do: async(String.split(command, " "), opts)

  def async([exec | args], opts) do
    stream_fn = parse_stream_option(opts)
    exec_path = resolve_exec_path(exec)

    cd = Keyword.get(opts, :cd, Path.dirname(exec))
    env = Keyword.get(opts, :env, [])

    spawn_opts = [:stderr_to_stdout, :binary, :exit_status, args: args, cd: cd, env: env]

    Task.async(fn ->
      start_time = DateTime.utc_now()
      port = Port.open({:spawn_executable, exec_path}, spawn_opts)
      handle_port(port, stream_fn, "", opts[:silenced], start_time)
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

  defp parse_stream_option(opts) do
    case Keyword.get(opts, :stream) do
      true -> &IO.write/1
      falsy when falsy in [nil, false] -> fn _ -> nil end
      func when is_function(func) -> func
    end
  end

  defp resolve_exec_path(exec) do
    cond do
      File.exists?(exec) -> exec
      path_to_exec = System.find_executable(Path.basename(exec)) -> path_to_exec
      true -> raise("executable not found: #{exec}")
    end
  end

  defp handle_port(port, stream_fn, output, silenced, start_time) do
    receive do
      {^port, {:data, data}} ->
        unless silenced, do: stream_fn.(data)
        handle_port(port, stream_fn, output <> data, silenced, start_time)

      {^port, {:exit_status, status}} ->
        duration = DateTime.diff(DateTime.utc_now(), start_time)
        {output, status, stream_fn, silenced, duration}

      :unsilence ->
        stream_fn.(output)
        handle_port(port, stream_fn, output, false, start_time)
    end
  end
end
