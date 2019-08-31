defmodule ExCheck.Config.Generator do
  @moduledoc false

  alias ExCheck.{Printer, Project}

  @generated_config """
  [
    ## all available options with default values (see `mix check` docs for description)
    # parallel: true,
    # skipped: true,

    ## list of tools (see `mix check` docs for defaults)
    tools: [
      ## curated tools may be disabled (e.g. the check for compilation warnings)
      # {:compiler, false},

      ## ...or adjusted (e.g. use one-line formatter for more compact credo output)
      # {:credo, "mix credo --format oneline"},

      ## ...or reordered (e.g. to see output from ex_unit before others)
      # {:ex_unit, order: -1},

      ## custom new tools may be added (mix tasks or arbitrary commands)
      # {:my_mix_task, command: "mix release", env: %{"MIX_ENV" => "prod"}},
      # {:my_arbitrary_tool, command: "npm test", cd: "assets"},
      # {:my_arbitrary_script, command: ["my_script", "argument with spaces"], cd: "scripts"}
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
