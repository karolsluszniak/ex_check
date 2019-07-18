defmodule Mix.Tasks.Check.Gen.Config do
  @moduledoc """
  Generates optional configuration file (`.check.exs`) for adjusting the check.
  """

  @shortdoc "Generates optional configuration file for adjusting the check"

  @switches []

  use Mix.Task
  alias ExCheck.Config

  @impl Mix.Task
  def run(args) do
    {_, _} = OptionParser.parse!(args, strict: @switches)

    Config.generate()
  end
end
