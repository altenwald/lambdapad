defmodule Lambdapad.Generate.Pages do
  alias Lambdapad.{Cli, Config, Generate, Html}
  alias Lambdapad.Generate.Sources

  def process(pages, cfg, mod, workdir, output_dir) do
    Enum.reduce(pages, cfg, fn {name, page_data}, config ->
      Cli.print_level2("Pages", name)
      page_data = Map.put(page_data, "name", name)
      format = page_data[:format]
      template_name = page_data[:template]
      render_mod = Html.init(name, template_name, workdir, format)

      pages =
        page_data
        |> Sources.get_files(workdir)
        |> process_transforms_on_item(mod, config, page_data)
        |> process_transforms_on_page(mod, config, page_data)

      chg_config = process_transforms_on_config(config, mod, pages, page_data)
      chg_config = generate_pages(pages, chg_config, name, page_data, output_dir, render_mod, mod)
      Cli.print_level2_ok()

      config
      |> Map.put(:url_data, chg_config[:url_data])
      |> Map.put(:links, chg_config[:links])
    end)
  end

  defp process_transforms_on_item(nil, _mod, _config, _page_data), do: nil
  defp process_transforms_on_item(pages, mod, config, page_data) do
    if transforms = Generate.resolve_transforms_on_item(mod, page_data) do
      for page <- pages do
        transforms.(page, config)
      end
    else
      pages
    end
  end

  defp process_transforms_on_page(nil, _mod, _config, _page_data), do: nil
  defp process_transforms_on_page(pages, mod, config, page_data) do
    if transforms = Generate.resolve_transforms_on_page(mod, page_data) do
      transforms.(pages, config)
    else
      pages
    end
  end

  defp process_transforms_on_config(config, _mod, nil, _page_data), do: config
  defp process_transforms_on_config(config, mod, pages, page_data) do
    if transforms = Generate.resolve_transforms_on_config(mod, page_data) do
      transforms.(config, pages)
    else
      config
    end
  end

  defp process_transforms_to_persist(mod, %{} = vars, %{} = page_data) do
    vars = Map.put(vars, "var_name", page_data[:var_name])
    if transforms = Generate.resolve_transforms_to_persist(mod, page_data) do
      transforms.(%{}, vars)
    else
      %{}
    end
  end

  defp generate_pages(nil, config, name, %{} = page_data, output_dir, render_mod, mod) do
    plist_config = Config.to_proplist(config)
    env_data = Enum.to_list(page_data[:env] || [])
    env = plist_config ++ env_data
    url = Generate.resolve_uri(config, name, page_data[:uri], env)
    file = Generate.build_file_abspath(output_dir, url, page_data[:uri_type])
    relative_file = String.replace_prefix(file, output_dir, "")
    Cli.print_level3(relative_file)
    iodata = Html.render(env_data, render_mod, plist_config, page_data[:format])
    File.write!(file, iodata)
    url_data = process_transforms_to_persist(mod, %{"__file__" => file}, page_data)
    links = gather_links(iodata)

    config
    |> Map.update(:url_data, [{url, url_data}], &[{url, url_data}|&1])
    |> Map.update(:links, links, &MapSet.union(&1, links))
  end

  defp generate_pages(pages, config, name, %{index: true, paginated: false} = page_data, output_dir, render_mod, mod) do
    plist_config = Config.to_proplist(config)
    vars = Generate.process_vars(page_data, pages)
    env_data = Enum.to_list(page_data[:env] || [])
    url = Generate.resolve_uri(config, name, page_data[:uri], vars ++ env_data)
    file = Generate.build_file_abspath(output_dir, url, page_data[:uri_type])
    relative_file = String.replace_prefix(file, output_dir, "")
    Cli.print_level3(relative_file)
    iodata = Html.render(vars ++ env_data, render_mod, plist_config, page_data[:format])
    File.write!(file, iodata)
    vars = Map.new([{"__file__", file}|vars])
    url_data = process_transforms_to_persist(mod, vars, page_data)
    links = gather_links(iodata)

    config
    |> Map.update(:url_data, [{url, url_data}], &[{url, url_data}|&1])
    |> Map.update(:links, links, &MapSet.union(&1, links))
  end

  defp generate_pages(pages, config, name, %{index: true} = page_data, output_dir, render_mod, mod) do
    items_per_page =
      case page_data[:paginated] do
        pg when is_function(pg) -> pg.(pages, config)
        pg when is_integer(pg) -> pg
      end

    page_items = Enum.chunk_every(pages, items_per_page)
    total_pages = length(page_items)
    pager_data = generate_pager_data(page_items, page_data, name, config)
    Enum.reduce(1..total_pages, config, fn index, cfg ->
      pager = get_pager(index, total_pages, pager_data)
      vars = pager_data[index][:vars]
      env_data = Enum.to_list(page_data[:env] || [])
      url = Path.join(config["blog"]["url"] || "", pager_data[index][:url])
      file = Generate.build_file_abspath(output_dir, url, page_data[:uri_type])
      relative_file = String.replace_prefix(file, output_dir, "")
      Cli.print_level3(relative_file)
      plist_config = Config.to_proplist(config)
      iodata = Html.render(vars ++ pager ++ env_data, render_mod, plist_config, page_data[:format])
      File.write!(file, iodata)
      vars = Map.new([{"__file__", file}|vars])
      url_data = process_transforms_to_persist(mod, vars, page_data)
      links = gather_links(iodata)

      cfg
      |> Map.update(:url_data, [{url, url_data}], &[{url, url_data}|&1])
      |> Map.update(:links, links, &MapSet.union(&1, links))
    end)
  end

  defp generate_pages(pages, config, name, %{} = page_data, output_dir, render_mod, mod) do
    Enum.reduce(pages, config, fn
      {index, data}, cfg ->
        vars = Generate.process_vars(page_data, data, index)
        env_data = Enum.to_list(page_data[:env] || [])
        url = Generate.resolve_uri(config, name, page_data[:uri], vars ++ env_data, index)
        file = Generate.build_file_abspath(output_dir, url, page_data[:uri_type])
        relative_file = String.replace_prefix(file, output_dir, "")
        Cli.print_level3(relative_file)
        plist_config = Config.to_proplist(config)
        iodata = Html.render(vars ++ env_data, render_mod, plist_config, page_data[:format])
        File.write!(file, iodata)
        vars = Map.new([{"__file__", file}|vars])
        url_data = process_transforms_to_persist(mod, vars, page_data)
        links = gather_links(iodata)

        cfg
        |> Map.update(:url_data, [{url, url_data}], &[{url, url_data}|&1])
        |> Map.update(:links, links, &MapSet.union(&1, links))

      data, cfg when is_map(data) ->
        vars = Generate.process_vars(page_data, data)
        env_data = Enum.to_list(page_data[:env] || [])
        url = Generate.resolve_uri(config, name, page_data[:uri], vars ++ env_data)
        file = Generate.build_file_abspath(output_dir, url, page_data[:uri_type])
        relative_file = String.replace_prefix(file, output_dir, "")
        Cli.print_level3(relative_file)
        plist_config = Config.to_proplist(config)
        iodata = Html.render(vars ++ env_data, render_mod, plist_config, page_data[:format])
        File.write!(file, iodata)
        vars = Map.new([{"__file__", file}|vars])
        url_data = process_transforms_to_persist(mod, vars, page_data)
        links = gather_links(iodata)

        cfg
        |> Map.update(:url_data, [{url, url_data}], &[{url, url_data}|&1])
        |> Map.update(:links, links, &MapSet.union(&1, links))
    end)
  end

  defp gather_links(html) do
    {:ok, document} = Floki.parse_document(html)
    for {"a", attrs, _} <- Floki.find(document, "a"), not is_nil(List.keyfind(attrs, "href", 0)) do
      {"href", link} = List.keyfind(attrs, "href", 0)
      link
    end
    |> MapSet.new()
  end

  defp generate_pager_data(page_items, page_data, name, config) do
    for {posts, index} <- Enum.with_index(page_items, 1), into: %{} do
      vars = Generate.process_vars(page_data, posts, index)
      url = Generate.resolve_uri(config, name, page_data[:uri], vars, index)
      {index, %{
        posts: posts,
        vars: vars,
        url: url
      }}
    end
  end

  defp get_pager(index, index, _pager_data) when index == 1 do
    [{"pager", []}]
  end
  defp get_pager(index, index, pager_data) do
    [{"pager", [{"prev_url", pager_data[index - 1][:url]}]}]
  end
  defp get_pager(1 = index, _total_pages, pager_data) do
    [{"pager", [{"next_url", pager_data[index + 1][:url]}]}]
  end
  defp get_pager(index, _total_pages, pager_data) do
    [{"pager", [
      {"next_url", pager_data[index + 1][:url]},
      {"prev_url", pager_data[index - 1][:url]}
    ]}]
  end
end
