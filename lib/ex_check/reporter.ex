defmodule ExCheck.Reporter do
  @moduledoc false

  # Behaviour for rendering the final check results. A reporter receives the full
  # list of result tuples once all tools have finished and is responsible for
  # producing the user-facing output for its format.
  #
  # Result tuples are `{status, {name, cmd, opts}, {exit_code, output, duration}}`
  # for run tools (status `:ok`/`:error`) and `{:skipped, name, reason}` for skipped
  # ones. `name` is an atom or `{atom, app}` for umbrella instances.

  @callback report(results :: [tuple], total_duration :: integer, opts :: keyword) :: :ok

  @formats %{
    pretty: ExCheck.Reporter.Pretty,
    json: ExCheck.Reporter.Json,
    agent: ExCheck.Reporter.Agent,
    github: ExCheck.Reporter.Github,
    junit: ExCheck.Reporter.Junit
  }

  @doc "Resolves a format atom to its reporter module."
  def resolve(format) do
    Map.get(@formats, format, ExCheck.Reporter.Pretty)
  end

  @doc "List of supported format atoms."
  def formats, do: @formats |> Map.keys() |> Enum.sort()

  @doc """
  Sink shared by the batch reporters (agent/json): writes the rendered report to the
  file given by `:output`, or to stdout when no output path is set.
  """
  # sobelow_skip ["Traversal.FileModule"]
  def emit(iodata, opts) do
    case Keyword.get(opts, :output) do
      nil -> IO.puts(iodata)
      path -> File.write!(path, iodata)
    end

    :ok
  end

  # Shared formatting helpers.

  @doc "Plain (uncolored) tool name, such as formatter or 'formatter in child'."
  def tool_name_string(name) when is_atom(name), do: Atom.to_string(name)
  def tool_name_string({name, app}), do: "#{name} in #{app}"

  @doc "Colored tool name iodata for terminal output."
  def format_tool_name(name) when is_atom(name), do: bright(name)
  def format_tool_name({name, app}) when is_atom(name), do: [bright(name), " in ", bright(app)]

  @doc "Command list joined into a single shell-like string."
  def command(cmd), do: Enum.join(cmd, " ")

  @doc "Formats a duration in seconds as `M:SS`."
  def format_duration(secs) do
    min = div(secs, 60)
    sec = rem(secs, 60)
    sec_str = if sec < 10, do: "0#{sec}", else: "#{sec}"

    "#{min}:#{sec_str}"
  end

  @doc "Wraps inner text in bright/normal ANSI markers."
  def bright(inner), do: [:bright, to_string(inner), :normal]

  @doc "Sort comparable for results: ok first, then errors, then skipped, by name."
  def summary_order({:ok, {name, _, _}, _}), do: {0, normalize_name(name)}
  def summary_order({:error, {name, _, _}, _}), do: {1, normalize_name(name)}
  def summary_order({:skipped, name, _}), do: {2, normalize_name(name)}

  defp normalize_name({_, _} = name), do: name
  defp normalize_name(name), do: {name, 0}

  @ansi_code_regex ~r/\x1b\[[0-9;]*[a-zA-Z]/

  @doc "Strips ANSI escape codes from captured tool output."
  def strip_ansi(output), do: String.replace(output, @ansi_code_regex, "")

  @doc "Whether a captured output block needs a trailing blank line for padding."
  def output_needs_padding?(output) do
    not (String.match?(output, ~r/\n{2,}$/) or output == "")
  end

  @doc "Splits a result name into `{name_string, app_string_or_nil}`."
  def split_name(name) when is_atom(name), do: {Atom.to_string(name), nil}
  def split_name({name, app}), do: {Atom.to_string(name), to_string(app)}

  @doc "Renders a skip reason as a plain string."
  def skip_reason_string({:elixir, version}),
    do: "Elixir version = #{System.version()}, not #{version}"

  def skip_reason_string({:deps, [name | _]}),
    do: "unsatisfied dependency #{tool_name_string(name)}"

  def skip_reason_string({:halted, name}),
    do: "halted after failure of #{tool_name_string(name)}"

  def skip_reason_string({:package, name}), do: "missing package #{name}"
  def skip_reason_string({:package, name, app}), do: "missing package #{name} in #{app}"
  def skip_reason_string({:file, name}), do: "missing file #{name}"
  def skip_reason_string({:cd, cd}), do: "missing directory #{cd}"
end
