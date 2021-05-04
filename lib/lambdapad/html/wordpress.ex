defmodule Lambdapad.Html.Wordpress do
  @wp_version "6.0"

  def init(name, template, workdir) when is_binary(name) and is_binary(template) do
    :ephp.start()
    :ephp_config.start_local()
    filepath = Path.join([workdir, "templates", template])

    %{
      code: :ephp_parser.file(filepath),
      template: filepath
    }
  end

  def get_path(filename, php_file) do
    filename
    |> Path.dirname()
    |> Path.join(php_file)
  end

  def render(vars, %{template: filename, code: code}, config) do
    {:ok, ctx} = :ephp.context_new(filename)
    :ephp.register_module(ctx, Lambdapad.Html.Wordpress.Theme)
    :ephp_context.set_bulk(ctx, [
      {"_BLOG", vars},
      {"_CONFIG", config},
      {"_TEMPLATE", filename},
      {"wp_version", @wp_version}
    ])
    {:ok, output} = :ephp_output.start_link(ctx, false)
    :ephp_context.set_output_handler(ctx, output)
    functions = get_path(filename, "functions.php")
    :ephp_lib_control.include(ctx, [line: 0, column: 0], {nil, functions})
    :ephp.eval(filename, ctx, code)
    html = :ephp_context.get_output(ctx)
    :ephp_context.destroy_all(ctx)
    html
  end
end
