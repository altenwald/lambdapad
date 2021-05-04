defmodule Lambdapad.Cli do

  alias Lambdapad.{Cli, Config, Generate, Http}
  alias Lambdapad.Generate.Sources

  @default_file "lambdapad.exs"
  @default_port 8080
  @default_verbosity 1

  defp absname("."), do: File.cwd!()
  defp absname(dir), do: Path.absname(dir)

  defp cwd!(lambdapad_file) do
    unless File.exists?(lambdapad_file) do
      IO.puts("File #{lambdapad_file} not found.")
      System.halt(1)
    end

    absname(Path.dirname(lambdapad_file))
  end

  def main(args) do
    args
    |> parse_options()
    |> commands(args)
  end

  def get_configs({calling_mod, _} = mod, rawargs), do: calling_mod.get_configs(mod, rawargs)

  def get_widgets({calling_mod, _} = mod, config), do: calling_mod.get_widgets(mod, config)

  def get_pages({calling_mod, _} = mod, config), do: calling_mod.get_pages(mod, config)

  def get_assets({calling_mod, _} = mod, config), do: calling_mod.get_assets(mod, config)

  def apply_transform({calling_mod, _} = mod, items), do: calling_mod.apply_transform(mod, items)

  def get_checks({calling_mod, _} = mod), do: calling_mod.get_checks(mod)

  defp compile(filename) do
    cond do
      String.ends_with?(filename, ".exs") ->
        Cli.Exs.compile(filename)

      String.ends_with?(filename, ".erl") ->
        Cli.Erl.compile(filename)

      :else ->
        IO.puts("File #{filename} unknown.")
        System.halt(1)
    end
  end

  def blocks(elements) when map_size(elements) == 1, do: "(1 block)"
  def blocks(elements), do: "(#{map_size(elements)} blocks)"

  defp commands(%_{args: %{infile: nil}} = params, rawargs) do
    commands(%{params | args: %{infile: @default_file}}, rawargs)
  end

  defp commands(%_{args: %{infile: filename}, flags: %{verbosity: loglevel}}, rawargs) do
    workdir = cwd!(filename)

    Application.put_env(:lambdapad, :workdir, workdir)
    Application.put_env(:lambdapad, :loglevel, loglevel)
    Sources.init()

    gt = print_level1("Reading configuration", filename)

    t = print_level2("Compiling", filename)
    {:ok, mod} = compile(filename)
    print_level2_ok()

    {:ok, config} = Config.init(get_configs(mod, rawargs), workdir)

    print_level2("Create directory")
    relative_output_dir = config["blog"]["output_dir"] || "site"
    print_level3(relative_output_dir)
    output_dir = Path.join([workdir, relative_output_dir])
    :ok = File.mkdir_p(output_dir)
    print_level2_ok()
    print_level1_ok(t)

    widgets_data = get_widgets(mod, config)
    config =
      if map_size(widgets_data) > 0 do
        t = print_level1("Processing widgets", blocks(widgets_data))
        widgets = Generate.Widgets.process(widgets_data, config, mod, workdir)
        config = Map.put(config, "widgets", widgets)
        print_level1_ok(t)
        config
      else
        config
      end

    pages_data = get_pages(mod, config)
    if map_size(pages_data) do
      t = print_level1("Processing pages", blocks(pages_data))
      Generate.Pages.process(pages_data, config, mod, workdir, output_dir)
      print_level1_ok(t)
    end

    checks = get_checks(mod)
    if map_size(checks) do
      t = print_level1("Processing checks")
      apply_finish_checks(checks, config)
      print_level1_ok(t)
    end

    assets_data = get_assets(mod, config)
    if map_size(assets_data) do
      t = print_level1("Processing assets", blocks(assets_data))
      Generate.Assets.process(assets_data, workdir)
      print_level1_ok(t)
    end

    gt = System.system_time(:millisecond) - gt
    IO.puts([IO.ANSI.blue(), "Done (#{gt / 1000}s)", IO.ANSI.reset()])
    Sources.terminate()
    :ok
  end

  defp commands({subcommand, %_{args: %{infile: nil}} = params}, rawargs) do
    commands({subcommand, %{params | args: %{infile: @default_file}}}, rawargs)
  end

  defp commands({[:clean], %_{args: %{infile: lambdapad_file}}}, rawargs) do
    workdir = cwd!(lambdapad_file)

    gt = print_level1("Reading configuration", lambdapad_file)

    t = print_level2("Compiling", lambdapad_file)
    {:ok, mod} = compile(lambdapad_file)
    print_level2_ok()

    {:ok, config} = Config.init(get_configs(mod, rawargs), workdir)
    print_level2_ok()
    print_level1_ok(t)

    dir = Path.join([workdir, config["blog"]["output_dir"] || "site"])
    if File.exists?(dir) do
      t = print_level1("Remove directory", dir)
      File.rm_rf!(dir)
      print_level1_ok(t)
    else
      print_level1("Doesn't exist", dir)
    end

    gt = System.system_time(:millisecond) - gt
    IO.puts([IO.ANSI.blue(), "Done (#{gt / 1000}s)", IO.ANSI.reset()])
    :ok
  end

  defp commands({[:http], %_{args: %{infile: lambdapad_file}, options: %{port: port}} = params}, rawargs) do
    workdir = cwd!(lambdapad_file)

    {:ok, mod} = compile(lambdapad_file)
    {:ok, config} = Config.init(get_configs(mod, rawargs), workdir)

    dir = Path.join([workdir, config["blog"]["output_dir"] || "site"])
    port = port || config["http"]["port"] || @default_port

    Http.start_server(port, dir)
    IO.puts([IO.ANSI.green(), "options", IO.ANSI.reset(), ": [q]uit or [r]ecompile"])
    if IO.gets("") == "r\n" do
      commands(%{params | options: %{}, flags: %{verbosity: @default_verbosity}}, rawargs)
      commands({[:http], params}, rawargs)
    end
  end

  defp commands({[:new, :list], _}, _rawargs) do
    IO.write("Available templates: ")

    list_templates()
    |> Enum.join(", ")
    |> IO.puts()
  end

  defp commands({[:new], %_{args: %{name: name}, options: %{template: template}, flags: %{verbosity: loglevel}}}, _rawargs) do
    if File.exists?(name) do
      IO.puts([IO.ANSI.red(), "error", IO.ANSI.reset(), ": cannot create #{name} directory."])
      System.halt(1)
    end

    files = get_template_files(template)
    unless files do
      IO.puts([IO.ANSI.red(), "error", IO.ANSI.reset(), ": template #{template} not found."])
      System.halt(1)
    end

    Application.put_env(:lambdapad, :loglevel, loglevel)

    t = print_level1("Creating project", name)
    print_level2("Creating directory", name)
    File.mkdir_p!(name)
    print_level2_ok()
    print_level2("Creating files")
    Enum.each(files, fn({file, content}) ->
      print_level3(file)
      filepath = Path.join([name, file])
      dirpath = Path.dirname(filepath)
      File.mkdir_p!(dirpath)
      File.write!(filepath, content)
    end)
    print_level2_ok()
    print_level1_ok(t)
  end

  defp apply_finish_checks(checks, config) do
    Enum.reduce(checks, config, fn
      {name, %{on: :finish, run: code}}, config ->
        print_level2("Checking", name)
        config = code.(config)
        print_level2_ok()
        config

      _, config -> config
    end)
  end

  Module.register_attribute(__MODULE__, :templates, accumulate: true)
  for "templates/" <> template <- Path.wildcard("templates/*") do
    files =
      Path.wildcard("templates/#{template}/**")
      |> Enum.filter(& File.regular?/1)

    @templates {template,
      for filepath <- files do
        file = String.replace_prefix(filepath, "templates/#{template}/", "")
        {file, File.read!(filepath)}
      end}
  end

  defp get_template_files(template) do
    case List.keyfind(@templates, template, 0) do
      {^template, files} -> files
      nil -> nil
    end
  end

  defp list_templates() do
    for {name, _} <- @templates, do: name
  end

  def print_error(msg) do
    IO.puts([IO.ANSI.red(), " error: ", msg, IO.ANSI.reset()])
  end

  def print_level1(name) do
    if Application.get_env(:lambdapad, :loglevel, 1) >= 2 do
      IO.puts([IO.ANSI.blue(), "*", IO.ANSI.reset(), " ", name, ":"])
    else
      IO.write([
        IO.ANSI.blue(), "*", IO.ANSI.reset(), " ", name, ":\n  ",
      ])
    end
    System.system_time(:millisecond)
  end

  def print_level1(name, annex) do
    if Application.get_env(:lambdapad, :loglevel, 1) >= 2 do
      IO.puts([
        IO.ANSI.blue(), "*", IO.ANSI.reset(), " ", name, ": ",
        IO.ANSI.green(), annex, IO.ANSI.reset()
      ])
    else
      IO.write([
        IO.ANSI.blue(), "*", IO.ANSI.reset(), " ", name, ": ",
        IO.ANSI.green(), annex, IO.ANSI.reset(), "\n  "
      ])
    end
    System.system_time(:millisecond)
  end

  def print_level1_ok(t) do
    t = System.system_time(:millisecond) - t
    if Application.get_env(:lambdapad, :loglevel, 1) >= 2 do
      IO.puts([IO.ANSI.blue(), "  Done (#{t / 1000}s)", IO.ANSI.reset()])
    else
      IO.puts([IO.ANSI.blue(), "\n  Done (#{t / 1000}s)", IO.ANSI.reset()])
    end
  end

  def print_level2(name) do
    if Application.get_env(:lambdapad, :loglevel, 1) >= 2 do
      IO.write([IO.ANSI.blue(), "  -", IO.ANSI.reset(), " ", name, " "])
    else
      IO.write([IO.ANSI.green(), ".", IO.ANSI.reset()])
    end
    System.system_time(:millisecond)
  end

  def print_level2(name, annex) do
    if Application.get_env(:lambdapad, :loglevel, 1) >= 2 do
      IO.write([
        IO.ANSI.blue(), "  -", IO.ANSI.reset(), " ", name, " ",
        IO.ANSI.yellow(), annex, IO.ANSI.reset(), " "])
    else
      IO.write([IO.ANSI.green(), ".", IO.ANSI.reset()])
    end
    System.system_time(:millisecond)
  end

  def print_level2_warn(msg) do
    if Application.get_env(:lambdapad, :loglevel, 1) >= 2 do
      IO.write([
        "\n    ", IO.ANSI.yellow(), "warning ", IO.ANSI.reset(), msg, "\n    "
      ])
    end
  end

  def print_level2_ok() do
    case Application.get_env(:lambdapad, :loglevel, 1) do
      2 -> IO.puts([IO.ANSI.green(), " ok", IO.ANSI.reset()])
      n when n >= 3 -> IO.write("\n")
      _ -> :ok
    end
  end

  def print_level3(name) do
    if Application.get_env(:lambdapad, :loglevel, 1) >= 3 do
      IO.write(["\n    ", IO.ANSI.blue(), "- ", IO.ANSI.reset(), name])
    else
      IO.write([IO.ANSI.blue(), ".", IO.ANSI.reset()])
    end
  end

  defp parse_options(args) do
    spec = Config.lambdapad_metainfo()["lambdapad"]
    infile = [infile: [
      value_name: "lambdapad.exs",
      help: "Specification to build your web site.",
      required: false,
      parser: :string
    ]]
    verbosity = [verbosity: [
      short: "-v",
      help: "Verbosity level.",
      multiple: true,
      default: 1
    ]]
    Optimus.new!(
      description: spec["name"],
      version: spec["vsn"],
      about: spec["description"],
      allow_unknown_args: false,
      parse_double_dash: true,
      args: infile,
      flags: verbosity,
      subcommands: [
        clean: [
          name: "clean",
          about: "Remove the output directory if exists",
          args: infile
        ],
        http: [
          name: "http",
          about: "HTTP Server for fast checking",
          args: infile,
          options: [
            port: [
              value_name: "PORT",
              short: "-p",
              long: "--port",
              help: "Port where to listen, by default it is 8080",
              parser: fn(p) ->
                case Integer.parse(p) do
                  {port, ""} when port >= 1024 -> {:ok, port}
                  {port, ""} -> {:error, "port must be greater than 1024, #{port} is invalid"}
                  {_, _} -> {:error, "you have to provide a port number"}
                end
              end,
              required: false
            ]
          ]
        ],
        new: [
          name: "new",
          about: "New project based on a template, check: new --list",
          args: [
            name: [
              value_name: "name",
              help: "Specify the name of the project to be created.",
              parser: :string,
              required: true
            ]
          ],
          flags: verbosity,
          options: [
            template: [
              value_name: "NAME",
              short: "-t",
              long: "--template",
              help: "Choose the template name (use --list to see available)",
              parser: :string,
              required: false,
              default: "blog"
            ]
          ],
          subcommands: [
            list: [
              name: "list",
              about: "List available templates"
            ]
          ]
        ]
      ]
    )
    |> Optimus.parse!(args)
  end
end
