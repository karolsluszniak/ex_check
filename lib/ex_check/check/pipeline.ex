defmodule ExCheck.Check.Pipeline do
  @moduledoc false

  # This function takes `pending` in a form of list of pending `payload`s. It executes
  # `opts[:start_fn]` with next `payload`s that have passed through `opts[:throttle_fn]` (which can
  # be used to manage cross-payload dependencies or to throttle the parallel execution).
  #
  # At the same time `opts[:collect_fn]` is called with result of `opts[:start_fn]`. This is done
  # sequentially in the order in which `opts[:start_fn]` were called. Each time `opts[:collect_fn]`
  # finishes, its result is collected and an attempt is made to start a new set of `opts[:start_fn]`
  # for nodes that now have all their dependencies collected.
  #
  # In the end it returns tuple with two lists:
  # - a list of results of finished calls to `opts[:collect_fn]`
  # - a list of payloads that were never reached because they were throttled out until the end

  def run(pending, opts) do
    loop({pending, [], nil, []}, opts)
  end

  defp loop({pending, running, collecting, finished}, opts) do
    {pending, running} = run_next(pending, running, finished, opts)
    {running, collecting} = collect_next(running, collecting)

    if collecting do
      receive do
        {:finished, payload, result} ->
          {pending, collecting, finished} = finish(payload, result, pending, collecting, finished)
          loop({pending, running, collecting, finished}, opts)
      end
    else
      {finished, pending}
    end
  end

  defp run_next(pending, running, finished, opts) do
    throttle_fn = Keyword.fetch!(opts, :throttle_fn)
    start_fn = Keyword.fetch!(opts, :start_fn)
    collect_fn = Keyword.fetch!(opts, :collect_fn)

    selected = select_next(pending, running, finished, throttle_fn)
    new_running = start_next(selected, start_fn, collect_fn)

    {pending -- selected, running ++ new_running}
  end

  defp select_next(pending, running, finished, throttle_fn) do
    throttle_fn.(pending, Enum.map(running, &elem(&1, 0)), finished)
  end

  defp start_next(new_running, start_fn, collect_fn) do
    Enum.map(new_running, fn payload ->
      runner_pid =
        spawn_link(fn ->
          payload = start_fn.(payload)

          receive do
            {:collect, collector_pid} ->
              result = collect_fn.(payload)
              send(collector_pid, {:result, result})
          end
        end)

      {payload, runner_pid}
    end)
  end

  defp collect_next([{payload, runner_pid} | rest], nil) do
    orchestrator_pid = self()

    spawn_link(fn ->
      collector_pid = self()
      send(runner_pid, {:collect, collector_pid})

      result =
        receive do
          {:result, result} -> result
        end

      send(orchestrator_pid, {:finished, payload, result})
    end)

    {rest, payload}
  end

  defp collect_next(running, collecting) do
    {running, collecting}
  end

  defp finish(payload, result, pending, collecting, finished) do
    collecting = if payload == collecting, do: nil, else: collecting
    finished = finished ++ [result]

    {pending, collecting, finished}
  end
end
