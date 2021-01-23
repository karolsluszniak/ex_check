defmodule ExCheck.Manifest do
  @moduledoc false

  def convert_retry_to_only(opts) do
    if Keyword.get(opts, :retry) do
      only =
        opts
        |> get_failed_tools()
        |> Enum.map(&{:only, &1})
        |> case do
          [] -> [{:only, "-"}]
          only -> only
        end

      opts ++ only
    else
      opts
    end
  end

  # sobelow_skip ["Traversal.FileModule", "DOS.StringToAtom"]
  def get_failed_tools(opts) do
    manifest_path = get_path(opts)

    if File.exists?(manifest_path) do
      manifest_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(fn
        "FAIL " <> tool -> deserialize_tool_name_without_app(tool)
        _ -> nil
      end)
      |> Enum.filter(& &1)
      |> Enum.map(&String.to_atom/1)
      |> Enum.uniq()
    else
      []
    end
  end

  defp deserialize_tool_name_without_app(name) do
    case String.split(name, "/") do
      [_app, tool] -> tool
      [tool] -> tool
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  def save(checks, opts) do
    lines = Enum.map(checks, &serialize_check/1)
    content = Enum.join(lines, "\n") <> "\n"
    path = get_path(opts)

    File.write!(path, content)
  end

  defp serialize_check({:ok, {name, _, _}, _}), do: "PASS #{serialize_tool_name(name)}"
  defp serialize_check({:error, {name, _, _}, _}), do: "FAIL #{serialize_tool_name(name)}"
  defp serialize_check({:skipped, name, _}), do: "SKIP #{serialize_tool_name(name)}"

  defp serialize_tool_name({tool, app}), do: "#{app}/#{tool}"
  defp serialize_tool_name(tool), do: tool

  @escape Enum.map(' [~#%&*{}\\:<>?/+|"]', &<<&1::utf8>>)

  defp get_path(opts) do
    Keyword.get_lazy(opts, :manifest, fn ->
      app_id = File.cwd!() |> String.replace(@escape, "_") |> String.replace(~r/^_+/, "")
      Path.join([System.tmp_dir!(), "ex_check-manifest-#{app_id}.txt"])
    end)
  end
end
