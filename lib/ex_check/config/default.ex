defmodule ExCheck.Config.Default do
  @moduledoc false

  # Default tool order tries to put short-running tools first in order for sequential output
  # streaming to display as many outputs as possible as soon as possible.
  @curated_tools [
    {:compiler, "mix compile --warnings-as-errors --force"},
    {:formatter, "mix format --check-formatted", detect: [{:file, ".formatter.exs"}]},
    {:credo, "mix credo", detect: [{:package, :credo}]},
    {:sobelow, "mix sobelow --exit", umbrella: [recursive: true], detect: [{:package, :sobelow}]},
    {:ex_doc, "mix docs", detect: [{:package, :ex_doc}]},
    {:ex_unit, "mix test", detect: [{:file, "test/test_helper.exs"}]},
    {:dialyzer, "mix dialyzer", detect: [{:package, :dialyxir}]},
    {:npm_test, "npm test", cd: "assets", detect: [{:file, "package.json", else: :disable}]}
  ]

  @default_config [
    parallel: true,
    skipped: true,
    tools: @curated_tools
  ]

  def get do
    @default_config
  end
end
