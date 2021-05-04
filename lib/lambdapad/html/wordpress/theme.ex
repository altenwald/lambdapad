defmodule Lambdapad.Html.Wordpress.Theme do
  import Record
  alias Lambdapad.Html.Wordpress

  @behaviour :ephp_func

  @default_html_lang "en"

  defrecord :variable, extract(:variable, from_lib: "ephp/include/ephp.hrl")

  def init_func do
    [
      add_action: [args: [:string, :callable, integer: 10, integer: 1]],
      add_action: [alias: "add_filter", args: [:string, :callable, integer: 10, integer: 1]],
      apply_filters: [args: [:string, :mixed]],
      bloginfo: [args: [string: ""]],
      body_class: [args: [mixed: ""]],
      esc_attr: [args: [:mixed]],
      esc_html_e: [args: [:string, string: "default"]],
      get_bloginfo: [args: [string: "", string: "raw"]],
      get_body_class: [args: [mixed: ""]],
      get_header: [args: []],
      get_language_attributes: [args: [string: "html"]],
      get_template_directory: [args: []],
      get_template_part: [args: [:string, string: :undefined, mixed: :ephp_array.new()]],
      get_theme_mod: [args: [:string, mixed: false]],
      has_custom_logo: [args: [integer: 0]],
      has_nav_menu: [args: [:string]],
      language_attributes: [args: [string: "html"]],
      wp_head: [args: []],
      wp_body_open: [args: []]
    ]
  end

  def init_const, do: []
  def init_config, do: []

  ## TODO
  def add_action(_ctx, _line, _tag, _function, _priority, _accepted_args), do: true

  ## TODO:
  def apply_filters(_ctx, _line, _tag, _value), do: true

  ## TODO:
  def esc_attr(_ctx, _line, {_, text}), do: text

  ## TODO:
  def esc_html_e(_ctx, _line, {_, text}, _domain), do: text

  defp get_var(ctx, line, name) do
    varpath = variable(name: name, line: line)
    :ephp_context.get(ctx, varpath)
  end

  def get_header(ctx, line) do
    template = get_var(ctx, line, "_TEMPLATE")
    header = Wordpress.get_path(template, "header.php")
    :ephp_lib_control.include(ctx, line, {:undefined, header})
  end

  def get_language_attributes(ctx, line, {_, _doctype}) do
    html_lang =
      get_var(ctx, line, "_CONFIG")
      |> Map.new()
      |> Map.get("html_lang", @default_html_lang)

    "xml:lang='#{html_lang}'"
  end

  ## TODO:
  def get_theme_mod(_ctx, _line, {_, _name}, {_, default}), do: default

  def get_template_part(ctx, line, {_, slug}, {_, :undefined}, {_, _args}) do
    template = get_var(ctx, line, "_TEMPLATE")
    part = Wordpress.get_path(template, slug <> ".php")
    :ephp_lib_control.include(ctx, line, {:undefined, part})
  end

  def get_template_part(ctx, line, {_, slug}, {_, name}, {_, _args}) do
    template = get_var(ctx, line, "_TEMPLATE")
    part = Wordpress.get_path(template, slug <> "-" <> name <> ".php")
    :ephp_lib_control.include(ctx, line, {:undefined, part})
  end

  ## TODO:
  def has_custom_logo(_ctx, _line, {_, _blog_id}), do: false

  ## TODO:
  def has_nav_menu(_ctx, _line, {_, _location}), do: false

  def language_attributes(ctx, line, doctype) do
    print(ctx, get_language_attributes(ctx, line, doctype))
  end

  def get_template_directory(ctx, line) do
    get_var(ctx, line, "_TEMPLATE")
    |> Path.dirname()
  end

  def bloginfo(ctx, line, key) do
    print(ctx, get_bloginfo(ctx, line, key, {:undefined, "display"}))
  end

  def get_bloginfo(ctx, line, {_, key}, {_, _display_or_raw}) do
    ## TODO: filter 'display' or 'raw'
    config = Map.new(get_var(ctx, line, "_CONFIG"))
    wordpress = Map.new(config["wordpress"] || [])
    blog = Map.new(config["blog"] || [])
    lambdapad = Map.new(config["lambdapad"] || [])
    case key do
      "" -> wordpress["name"] || blog["name"] || :undefined
      "name" -> wordpress["name"] || blog["name"] || :undefined
      "url" -> wordpress["home_url"] || blog["url"] || :undefined
      "wpurl" -> wordpress["site_url"] || blog["url"] || :undefined
      "charset" -> wordpress["charset"] || "UTF-8"
      "version" -> lambdapad["vsn"]
      key -> wordpress[key] || :undefined
    end
  end

  def body_class(ctx, line, class) do
    text = "class='#{Enum.join(get_body_class(ctx, line, class), " ")}'"
    print(ctx, text)
  end

  ## TODO:
  def get_body_class(_ctx, _line, {_, _class}) do
    ["home", "blog"]
  end

  defp print(ctx, text) do
    :ephp_context.set_output(ctx, text)
    :undefined
  end

  # TODO:
  def wp_head(_ctx, _line), do: :undefined

  # TODO:
  def wp_body_open(_ctx, _line), do: :undefined
end
