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

  def unsilence(%Task{pid: pid} = task) do
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

  defp handle_port(port, stream_fn, output, pending, silenced, start_time) do
    receive do
      {^port, {:data, data}} ->
        data =
          if output == "",
            do: String.replace(data, ~r/^\s*/, ""),
            else: data

        pending =
          if silenced,
            do: pending,
            else: stream_complete(stream_fn, pending <> data)

        handle_port(port, stream_fn, output <> data, pending, silenced, start_time)

      {^port, {:exit_status, status}} ->
        unless silenced || pending == "", do: stream_fn.(pending)
        duration = DateTime.diff(DateTime.utc_now(), start_time)
        {output, status, stream_fn, silenced, duration}

      :unsilence ->
        pending = stream_complete(stream_fn, output)
        handle_port(port, stream_fn, output, pending, false, start_time)
    end
  end

  # A port delivers whatever bytes the pipe holds, so a chunk can end inside a
  # multi-byte UTF-8 character, and IO.write/1 raises ArgumentError on such a
  # chunk. Stream the complete characters and hold back an incomplete trailing
  # sequence until the next chunk completes it. Invalid bytes pass through as
  # before.
  defp stream_complete(stream_fn, bytes) do
    {complete, pending} =
      case :unicode.characters_to_binary(bytes) do
        {:incomplete, complete, pending} -> {complete, pending}
        _complete_or_invalid -> {bytes, ""}
      end

    if complete != "", do: stream_fn.(complete)
    pending
  end
end
