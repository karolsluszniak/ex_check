defmodule ExCheck.Config.Generator do
  @moduledoc false

  alias ExCheck.Printer
  alias ExCheck.Project

  @generated_config """
  [
    ## don't run tools concurrently
    # parallel: false,

    ## don't print info about skipped tools
    # skipped: false,

    ## always run tools in fix mode (put it in ~/.check.exs locally, not in project config)
    # fix: true,

    ## don't retry automatically even if last run resulted in failures
    # retry: false,

    ## list of tools (see `mix check` docs for a list of default curated tools)
    tools: [
      ## curated tools may be disabled (e.g. the check for compilation warnings)
      # {:compiler, false},

      ## ...or have command & args adjusted (e.g. enable skip comments for sobelow)
      # {:sobelow, "mix sobelow --exit --skip"},

      ## ...or reordered (e.g. to see output from dialyzer before others)
      # {:dialyzer, order: -1},

      ## ...or reconfigured (e.g. disable parallel execution of ex_unit in umbrella)
      # {:ex_unit, umbrella: [parallel: false]},

      ## custom new tools may be added (Mix tasks or arbitrary commands)
      # {:my_task, "mix my_task", env: %{"MIX_ENV" => "prod"}},
      # {:my_tool, ["my_tool", "arg with spaces"]}
    ]
  ]
  """

  @config_filename ".check.exs"

  # sobelow_skip ["Traversal.FileModule"]
  def generate do
    target_path =
      Project.get_mix_root_dir()
      |> Path.join(@config_filename)
      |> Path.expand()

    formatted_path = Path.relative_to_cwd(target_path)

    if File.exists?(target_path) do
      Printer.info([:yellow, "* ", :bright, formatted_path, :normal, " already exists, skipped"])
    else
      Printer.info([:green, "* creating ", :bright, formatted_path])

      File.write!(target_path, @generated_config)
    end
  end
end
