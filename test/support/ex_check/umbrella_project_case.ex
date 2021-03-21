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

      setup context do
        tmp_dir = create_tmp_directory()
        project_dir = create_mix_project(tmp_dir, umbrella: true)
        apps_dir = Path.join(project_dir, "apps")

        child_a_dir = create_mix_project(apps_dir, name: "child_a")
        child_b_dir = create_mix_project(apps_dir, name: "child_b")
        project_dirs = [project_dir, child_a_dir, child_b_dir]

        ex_check_dir = Path.join([project_dir, "priv", "ex_check"])
        copy_ex_check_dep(ex_check_dir)

        set_mix_deps(project_dir, ex_check: ex_check_dir)

        if context[:copy_ex_check_to_children] do
          set_mix_deps([child_a_dir, child_b_dir], ex_check: ex_check_dir)
        else
          set_mix_deps([child_a_dir, child_b_dir])
        end

        write_default_config(project_dir)
        on_exit(fn -> remove_tmp_directory(tmp_dir) end)

        {:ok, project_dirs: project_dirs}
      end
    end
  end

  def create_tmp_directory do
    rand = Integer.to_string(:rand.uniform(4_294_967_296), 32)

    tmp_dir =
      System.tmp_dir!()
      |> Path.join("ex_check_test")
      |> Path.join("#{rand}")

    File.mkdir_p!(tmp_dir)

    tmp_dir
  end

  def remove_tmp_directory(tmp_dir) do
    File.rm_rf!(tmp_dir)
  end

  def copy_ex_check_dep(ex_check_dir) do
    if not File.exists?(ex_check_dir) do
      File.mkdir_p!(ex_check_dir)
    end

    File.cp_r!(File.cwd!(), ex_check_dir)
  end

  def create_mix_project(root_dir, opts \\ []) do
    name = Keyword.get(opts, :name, "test_project")
    umbrella = Keyword.get(opts, :umbrella, false)
    args = if umbrella, do: ["--umbrella"], else: []

    System.cmd("mix", ["new", name] ++ args, cd: root_dir)

    Path.join(root_dir, name)
  end

  def set_mix_deps(project_dirs, deps \\ [])

  def set_mix_deps(project_dirs, deps) when is_list(project_dirs) do
    Enum.map(project_dirs, &set_mix_deps(&1, deps))
  end

  def set_mix_deps(project_dir, deps) do
    config_path = "#{project_dir}/mix.exs"
    deps_from = ~r/ *defp deps.*end\n/Us

    deps_list =
      Enum.map(deps, fn dep ->
        case dep do
          {name, path} ->
            "{:#{name}, path: \"#{path}\", only: [:dev, :test], runtime: false}"

          name ->
            "{:#{name}, \">= 0.0.0\", only: [:dev, :test], runtime: false}"
        end
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
end
