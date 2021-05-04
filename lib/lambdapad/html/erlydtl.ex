defmodule Lambdapad.Html.Erlydtl do
  alias Lambdapad.Cli

  def init(name, html_file, workdir) when is_binary(name) do
    module = Module.concat([__MODULE__, Macro.camelize(name)])
    if not function_exported?(module, :__info__, 1) do
      templates_dir = Path.join([workdir, "templates"])
      html_file_path = to_charlist(Path.join([templates_dir, html_file]))
      opts = [
        :return,
        libraries: [
          {"widget", Lambdapad.Html.Erlydtl.Widget},
          {"filters", Lambdapad.Html.Erlydtl.Filters}
        ],
        default_libraries: ["widget", "filters"]
      ]
      case :erlydtl.compile_file(html_file_path, module, opts) do
        {:ok, _module, warnings} ->
          warnings = filter_warnings(warnings)
          if warnings != [] do
            Cli.print_level2_warn("#{inspect(warnings)}")
          end
          module

        {:error, error, []} ->
          raise """
          template #{inspect(name)} file #{inspect(html_file)} not found

          error: #{inspect(error)}
          """
      end
    else
      module
    end
  end

  defp filter_warnings(warnings) do
    filter_warnings(warnings, [])
  end

  defp filter_warnings([], acc), do: acc
  defp filter_warnings([{_file, [{:none, _, :no_out_dir}]} | rest], acc) do
    filter_warnings(rest, acc)
  end
  defp filter_warnings([{'', [{_n, :sys_core_fold, :useless_building}]} | rest], acc) do
    filter_warnings(rest, acc)
  end
  defp filter_warnings([warning|rest], acc) do
    filter_warnings(rest, [warning|acc])
  end

  def render(vars, module, config) when is_atom(module) do
    vars = vars ++ config
    {:ok, data} = apply(module, :render, [vars, config])
    IO.iodata_to_binary(data)
  end
end
