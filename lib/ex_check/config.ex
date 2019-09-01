defmodule ExCheck.Config do
  @moduledoc false

  alias __MODULE__.{Generator, Loader}

  defdelegate generate, to: Generator
  defdelegate load, to: Loader
end
