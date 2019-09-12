defmodule ExCheck.UmbrellaProjectCases.AssetTestingTest do
  use ExCheck.UmbrellaProjectCase, async: true

  @package_json """
  {
    "scripts": {
      "test": "echo \\"Error: no test specified\\" && exit 1"
    }
  }
  """

  test "asset testing", %{project_dirs: [project_root_dir, child_a_dir | _]} do
    package_json_path = Path.join([child_a_dir, "assets", "package.json"])
    File.mkdir_p!(Path.dirname(package_json_path))
    File.write!(package_json_path, @package_json)

    assert({output, 1} = System.cmd("mix", ~w[check], cd: project_root_dir))

    assert output =~ "npm_test in child_a error code 1"
    refute output =~ "npm_test in child_b"
  end
end
