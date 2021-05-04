defmodule Lambdapad.Html.Erlydtl.Filters do
  @behaviour :erlydtl_library

  def version, do: 1

  def inventory(:filters), do: [:read_file, :markdown_to_html]

  def inventory(:tags), do: []

  defp abs_filename("/" <> _ = filename), do: filename
  defp abs_filename(relative_name) do
    Path.join([Application.get_env(:lambdapad, :workdir, ""), relative_name])
  end

  def read_file(:undefined), do: ""
  def read_file(file) do
    file
    |> abs_filename()
    |> File.read!()
  end

  def read_file(:undefined, _), do: ""
  def read_file(file, lines_spec) do
    file = abs_filename(file)
    {first, last} = parse_lines(lines_spec)

    file
    |> abs_filename()
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.drop_while(fn {_, i} -> i < first end)
    |> Stream.take_while(fn {_, i} -> last == :infinity or i <= last end)
    |> Enum.map(fn {line, _} -> line end)
  end

  defp parse_lines(spec) do
    pattern = ~r/^([0-9]+)?:(-?[0-9]+)?$/
    opts = [:binary, capture: :all_but_first]
    match_to_lines(Regex.run(pattern, spec, opts), spec)
  end

  defp match_to_lines([], _spec), do: {1, :infinity}
  defp match_to_lines([first], _spec), do: {String.to_integer(first), :infinity}
  defp match_to_lines(["", last], _spec), do: {1, String.to_integer(last)}
  defp match_to_lines([first, last], _spec), do: {String.to_integer(first), String.to_integer(last)}
  defp match_to_lines(nil, spec), do: throw({:lines_spec, spec})

  def markdown_to_html(:undefined), do: ""
  def markdown_to_html(text) do
    {_status, html, _messages} = Earmark.as_html(text, smartypants: false, gfm_tables: true, footnotes: true)
    {:safe, html}
  end
end
