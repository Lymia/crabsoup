--!strict

local utils = require("crabsoup.utils")

local plugins = {}

local function nyi(name)
    plugins[name] = function(globals)
        Log.error(`Built-in widget '{name}' is not yet implemented!`)
    end
end

--
-- Include plugin
--
function plugins.include(globals)
    -- Check parameters
    if not globals.config.file then
        Plugin.fail(`include plugin requires a 'file' parameter to be given`)
    end
    if not globals.config.selector then
        Log.warn(`include plugin requires a 'selector' parameter to be do anything`)
        return
    end

    -- Read and parse the input file
    local contents = Sys.read_file(globals.config.file)
    local data
    if globals.config.parse == nil or globals.config.parse then
        data = HTML.parse(contents)
    else
        data = HTML.create_text(contents)
    end

    -- Insert the template into every matching selector
    local action = utils.lookup_action(globals.config.action or "append")
    local selector = utils.parse_toml_selector(globals.config.selector)

    local selection = HTML.select(globals.page, selector)
    if #selection == 1 then
        action(selection[1], data)
    else
        Table.iter_values(function(x) action(x, HTML.clone(data)) end, selection)
    end
end

nyi("insert_html")
nyi("exec")
nyi("preprocess_element")
nyi("title")
nyi("footnotes")
nyi("toc")
nyi("breadcrumbs")
nyi("delete_element")
nyi("wrap")
nyi("relative_links")
nyi("absolute_links")

return plugins
