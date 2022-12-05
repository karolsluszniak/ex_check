defmodule ExCheck.UmbrellaProjectCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  @default_config """
  [
    fix: false
  ]
  """

  using do
    quote do
      import ExCheck.UmbrellaProjectCase

      @moduletag timeout: 5 * 60 * 1_000

      setup do
        tmp_dir = create_tmp_directory()
        root_project_dir = create_mix_project(tmp_dir, umbrella: true)
        apps_dir = Path.join(root_project_dir, "apps")
        child_a_dir = create_mix_project(apps_dir, name: "child_a")
        child_b_dir = create_mix_project(apps_dir, name: "child_b")
        project_dirs = [root_project_dir, child_a_dir, child_b_dir]

        copy_ex_check_dep(root_project_dir)
        set_mix_deps(root_project_dir, project_dirs, [:ex_check])
        write_default_config(root_project_dir)
        on_exit(fn -> remove_tmp_directory(tmp_dir) end)

        {:ok, project_dirs: project_dirs}
      end
    end
  end

  def create_tmp_directory do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    unique_id = :crypto.strong_rand_bytes(12) |> Base.url_encode64()

    tmp_dir =
      System.tmp_dir!()
      |> Path.join("ex_check_test")
      |> Path.join("#{timestamp}-#{unique_id}")

    File.mkdir_p!(tmp_dir)

    tmp_dir
  end

  def remove_tmp_directory(tmp_dir) do
    File.rm_rf!(tmp_dir)
  end

  def create_mix_project(root_dir, opts \\ []) do
    name = Keyword.get(opts, :name, "test_project")
    umbrella = Keyword.get(opts, :umbrella, false)
    args = if umbrella, do: ["--umbrella"], else: []

    System.cmd("mix", ["new", name] ++ args, cd: root_dir)

    Path.join(root_dir, name)
  end

  def copy_ex_check_dep(root_project_dir) do
    ex_check_dir = get_ex_check_dep_dir(root_project_dir)

    if not File.exists?(ex_check_dir) do
      File.mkdir_p!(ex_check_dir)
    end

    File.cp_r!(File.cwd!(), ex_check_dir)
  end

  def set_mix_deps(root_project_dir, project_dirs, deps) when is_list(project_dirs) do
    Enum.map(project_dirs, &set_mix_deps(root_project_dir, &1, deps))
  end

  def set_mix_deps(root_project_dir, project_dir, deps) do
    ex_check_dir = get_ex_check_dep_dir(root_project_dir)
    config_path = "#{project_dir}/mix.exs"
    deps_from = ~r/ *defp deps.*end\n/Us

    deps_list =
      Enum.map(deps, fn
        :ex_check ->
          "{:ex_check, path: \"#{ex_check_dir}\", only: [:dev, :test], runtime: false}"

        dep ->
          "{:#{dep}, \">= 0.0.0\", only: :dev, runtime: false}"
      end)

    deps_to = """
      defp deps do
        [
          #{Enum.join(deps_list, ",\n      ")}
        ]
      end
    """

    new_config =
      config_path
      |> File.read!()
      |> String.replace(deps_from, deps_to)

    unless String.contains?(new_config, "ex_check"), do: raise("unable to add ex_check dep")

    File.write!(config_path, new_config)
    {_, 0} = System.cmd("mix", ~w[format], cd: project_dir)
    {_, 0} = System.cmd("mix", ~w[deps.get], cd: project_dir)
  end

  def set_mix_app_mod(project_dir, mod) do
    config_path = "#{project_dir}/mix.exs"
    app_from = ~r/ *def application.*end\n/Us

    app_to = """
      def application do
        [
          mod: {#{mod}, []}
        ]
      end
    """

    new_config =
      config_path
      |> File.read!()
      |> String.replace(app_from, app_to)

    unless String.contains?(new_config, mod), do: raise("unable to set #{mod} app mod")

    File.write!(config_path, new_config)
    {_, 0} = System.cmd("mix", ~w[format], cd: project_dir)
  end

  def write_default_config(project_dir) do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @default_config)
  end

  defp get_ex_check_dep_dir(root_project_dir) do
    Path.join([root_project_dir, "priv", "ex_check"])
  end
end
