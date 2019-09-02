defmodule ExCheck.Check.Pipeline do
  @moduledoc false

  # This function takes `graph` in a form of list of tuples `{:a, [:b, :c], payload}` where:
  # - `:a` is specific node's name
  # - `[:b, :c]` are names of nodes that `:a` depends on
  # - `payload` is arbitrary data used to call `opts[:start_fn]`
  #
  # It executes `opts[:start_fn]` with `payload` for nodes without uncollected dependencies that
  # have passed through `opts[:throttle_fn]` (which can be used to throttle the parallel execution).
  #
  # At the same time `opts[:collect_fn]` is called with result of `opts[:start_fn]`. This is done
  # sequentially in the order in which `opts[:start_fn]` were called. Each time `opts[:collect_fn]`
  # finishes, its result is collected and an attempt is made to start a new set of `opts[:start_fn]`
  # for nodes that now have all their dependencies collected.
  #
  # In the end it returns tuple with two lists:
  # - a list of results of finished calls to `opts[:collect_fn]`
  # - a list of nodes that were never reached e.g. due to missing nodes or circular dependencies in
  #   form of tuples `{:a, [:b], payload}` where `[:b]` is a list of remaining dependencies

  def run(graph, opts) do
    loop({graph, [], nil, []}, opts)
  end

  defp loop({pending, running, collecting, finished}, opts) do
    {pending, running} = run_next(pending, running, opts)
    {running, collecting} = collect_next(running, collecting)

    if collecting do
      receive do
        {:finished, name, result} ->
          {pending, collecting, finished} = finish(name, result, pending, collecting, finished)
          loop({pending, running, collecting, finished}, opts)
      end
    else
      {finished, pending}
    end
  end

  defp run_next(pending, running, opts) do
    throttle_fn = Keyword.fetch!(opts, :throttle_fn)
    start_fn = Keyword.fetch!(opts, :start_fn)
    collect_fn = Keyword.fetch!(opts, :collect_fn)

    selected = select_next(pending, running, throttle_fn)
    new_running = start_next(selected, start_fn, collect_fn)

    {pending -- selected, running ++ new_running}
  end

  defp select_next(pending, running, throttle_fn) do
    selected_no_deps = Enum.filter(pending, fn {_, deps, _} -> deps == [] end)

    throttle_fn.(selected_no_deps, running)
  end

  defp start_next(new_running, start_fn, collect_fn) do
    Enum.map(new_running, fn {name, _, payload} ->
      runner_pid =
        spawn_link(fn ->
          payload = start_fn.(payload)

          receive do
            {:collect, collector_pid} ->
              result = collect_fn.(payload)
              send(collector_pid, {:result, result})
          end
        end)

      {name, runner_pid}
    end)
  end

  defp collect_next([{name, runner_pid} | rest], nil) do
    orchestrator_pid = self()

    spawn_link(fn ->
      collector_pid = self()
      send(runner_pid, {:collect, collector_pid})

      result =
        receive do
          {:result, result} -> result
        end

      send(orchestrator_pid, {:finished, name, result})
    end)

    {rest, name}
  end

  defp collect_next(running, collecting) do
    {running, collecting}
  end

  defp finish(name, result, pending, collecting, finished) do
    pending = Enum.map(pending, fn {n, deps, t} -> {n, List.delete(deps, name), t} end)
    collecting = if name == collecting, do: nil, else: collecting
    finished = finished ++ [result]

    {pending, collecting, finished}
  end
end
