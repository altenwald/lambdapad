defmodule Lambdapad.Html.Erlydtl.Widget do
  @behaviour :erlydtl_library

  def version, do: 1

  def inventory(:filters), do: []

  def inventory(:tags), do: [:widget]

  def widget([name], config) do
    {"widgets", widgets} = List.keyfind(config, "widgets", 0)
    case List.keyfind(widgets, name, 0) do
      {^name, content} -> content
      nil -> raise "widget #{inspect(name)} not found!"
    end
  end
end
