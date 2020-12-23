defmodule ExCheck.Manifest do
  @moduledoc false

  # sobelow_skip ["Traversal.FileModule", "DOS.StringToAtom"]
  def convert_failed_to_only(opts) do
    with true <- Keyword.get(opts, :failed),
         manifest_path = get_path(opts),
         true <- File.exists?(manifest_path) do
      only =
        manifest_path
        |> File.read!()
        |> String.split("\n")
        |> Enum.map(fn
          "FAIL " <> tool -> deserialize_tool_name_without_app(tool)
          _ -> nil
        end)
        |> Enum.filter(& &1)
        |> Enum.map(&{:only, String.to_atom(&1)})
        |> case do
          [] -> [{:only, "-"}]
          only -> only
        end

      opts ++ only
    else
      _ -> opts
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
