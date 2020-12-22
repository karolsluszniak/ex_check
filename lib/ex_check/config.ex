defmodule ExCheck.Config do
  @moduledoc false

  defdelegate generate, to: ExCheck.Config.Generator
  defdelegate load(opts), to: ExCheck.Config.Loader
end
