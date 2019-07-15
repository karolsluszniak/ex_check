defmodule ExCheck.Config do
  @moduledoc false

  alias ExCheck.{Printer, Project}

  @curated_checks [
    {:compiler, command: "mix compile --warnings-as-errors --force"},
    {:formatter, command: "mix format --check-formatted", require_files: [".formatter.exs"]},
    {:credo, command: "mix credo", require_deps: [:credo]},
    {:dialyzer, command: "mix dialyzer --halt-exit-status", require_deps: [:dialyxir]},
    {:ex_unit, command: "mix test", require_files: ["test/test_helper.exs"]},
    {:ex_doc, command: "mix docs", require_deps: [:ex_doc]}
  ]

  @default_config [
    parallel: true,
    exit_status: true,
    skipped: true,
    checks: @curated_checks
  ]

  @option_list [:parallel, :exit_status, :skipped]

  @config_filename ".check.exs"

  def get_opts(config) do
    Keyword.take(config, @option_list)
  end

  def get_checks(config) do
    Keyword.fetch!(config, :checks)
  end

  def load do
    Enum.reduce([Project.get_root_dir()], @default_config, fn next_config_dir, config ->
      next_config_filename =
        next_config_dir
        |> Path.join(@config_filename)
        |> Path.expand()

      if File.exists?(next_config_filename) do
        {next_config, _} = Code.eval_file(next_config_filename)
        merge_config(config, next_config)
      else
        config
      end
    end)
  end

  defp merge_config(config, next_config) do
    config_opts = Keyword.take(config, @option_list)
    next_config_opts = Keyword.take(next_config, @option_list)
    merged_opts = Keyword.merge(config_opts, next_config_opts)

    config_checks = Keyword.fetch!(config, :checks)
    next_config_checks = Keyword.get(next_config, :checks, [])

    merged_checks =
      Enum.reduce(next_config_checks, config_checks, fn next_check, checks ->
        next_check_name = elem(next_check, 0)
        check = List.keyfind(checks, next_check_name, 0)
        merged_check = merge_check(check, next_check)
        List.keystore(checks, next_check_name, 0, merged_check)
      end)

    Keyword.put(merged_opts, :checks, merged_checks)
  end

  defp merge_check(check, next_check)
  defp merge_check(nil, next_check), do: next_check
  defp merge_check({name, false}, next_check = {name, _}), do: next_check
  defp merge_check({name, _}, next_check = {name, false}), do: next_check
  defp merge_check({name, opts}, {name, next_opts}), do: {name, Keyword.merge(opts, next_opts)}

  @generated_config """
  [
    # all available options with default values
    skipped: true,
    exit_status: true,
    parallel: true,

    # check list (see the `mix check` docs for the list of default ones)
    checks: [
      ## curated checks may be disabled (e.g. the check for compilation warnings)
      # {:compiler, false},

      ## ...or adjusted (e.g. additionally dump test coverage along with test run)
      # {:ex_unit, command: "mix test --cover"},

      ## custom new checks may be added
      # {:my_mix_check, command: "mix some_task"},
      # {:my_other_check, command: "my_cmd"}
    ]
  ]

  """

  def generate do
    target_path =
      Project.get_root_dir()
      |> Path.join(@config_filename)
      |> Path.expand()

    formatted_path = Path.relative_to_cwd(target_path)

    if File.exists?(target_path) do
      Printer.info([:yellow, "=> ", :bright, formatted_path, :normal, " already exists, skipped"])
    else
      Printer.info([:green, "=> creating ", :bright, formatted_path])

      File.write!(target_path, @generated_config)
    end
  end
end
