defmodule ExCheck.Command do
  @moduledoc false

  def run(command, opts \\ []) do
    command
    |> async(opts)
    |> await()
  end

  def async(command, opts \\ [])

  def async(command, opts) when is_binary(command), do: async(String.split(command, " "), opts)

  def async(args, opts) do
    {env, [exec | args]} = extract_env(args)
    stream_fn = parse_stream_option(opts)
    exec_path = resolve_exec_path(exec)

    cd = Keyword.get(opts, :cd, Path.dirname(exec))

    env =
      env
      |> Map.new()
      |> Map.merge(Keyword.get(opts, :env, %{}))
      |> Map.to_list()
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

  defp extract_env(list) do
    {env, args} = Enum.split_while(list, &String.match?(&1, ~r/^[A-Z_]+=\w+$/))

    env_tuples =
      Enum.map(env, fn env_string ->
        [[name, value]] = Regex.scan(~r/^([A-Z_]+)=(\w+)$/, env_string, capture: :all_but_first)
        {name, value}
      end)

    {env_tuples, args}
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
