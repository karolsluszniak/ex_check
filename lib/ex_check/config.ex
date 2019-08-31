defmodule ExCheck.Config do
  @moduledoc false

  alias __MODULE__.{Loader, Generator}

  def load do
    Loader.load()
  end

  def generate do
    Generator.generate()
  end

  def get_opts(config) do
    Keyword.take(config, [:parallel, :skipped])
  end

  def get_tools(config) do
    Keyword.fetch!(config, :tools)
  end
end
