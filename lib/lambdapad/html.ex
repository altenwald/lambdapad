defmodule Lambdapad.Html do
  alias Lambdapad.Html

  def init(name, html_file, workdir, :erlydtl) when is_binary(name) do
    Html.Erlydtl.init(name, html_file, workdir)
  end

  def init(name, theme, workdir, :wordpress) when is_binary(name) do
    Html.Wordpress.init(name, theme, workdir)
  end

  def render(vars, module, config, :erlydtl) do
    Html.Erlydtl.render(vars, module, config)
  end

  def render(vars, theme, config, :wordpress) do
    Html.Wordpress.render(vars, theme, config)
  end
end
