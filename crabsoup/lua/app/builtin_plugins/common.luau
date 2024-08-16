--!strict

local utils = require("crabsoup.utils")

local plugins = {} :: { [string]: (any) -> () }

local function nyi(name)
    plugins[name] = function(globals)
        Log.error(`Built-in widget '{name}' is not yet implemented!`)
    end
end

local function parse_html(globals, contents)
    if globals.config.parse == nil or globals.config.parse then
        return HTML.parse_fragment(contents, globals.config.fragment_root or "main")
    else
        return HTML.create_text(contents)
    end
end

local function insert_by_selector(globals, data)
    -- Insert the template into every matching selector
    local action = utils.lookup_action(globals.config.action or "append")
    local selector = utils.parse_toml_selector(globals.config.selector)

    local selection = HTML.select(globals.page, selector)
    if #selection == 1 then
        action(selection[1], data)
    else
        Table.iter_values(function(x)
            action(x, HTML.clone(data))
        end, selection)
    end
end

--
-- `include` plugin
--
-- params: file, selector, parse, action, fragment_root
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
    local data = parse_html(globals, Sys.read_file(globals.config.file))

    -- Insert the template into every matching selector
    insert_by_selector(globals, data)
end

--
-- `insert_html` plugin
--
-- params: html, selector, parse, fragment_root
--
function plugins.insert_html(globals)
    -- Check parameters
    if not globals.config.html then
        Plugin.fail(`insert_html plugin requires a 'html' parameter to be given`)
    end

    -- Read and parse the HTML
    local data = parse_html(globals, globals.config.html)

    -- Insert the template into every matching selector
    insert_by_selector(globals, data)
end

--
-- `delete_element` plugin
--
-- params: selector, when_no_child
--
function plugins.delete_element(globals)
    -- Delete each matching element
    local selector = utils.parse_toml_selector(globals.config.selector)
    local no_child_selector = utils.parse_toml_selector(globals.config.when_no_child)
    if globals.config.when_no_child then
        Table.iter_values(function(x)
            if not HTML.select(x, no_child_selector) then
                HTML.delete(x)
            end
        end, HTML.select(globals.page, selector))
    else
        Table.iter_values(HTML.delete, HTML.select(globals.page, selector))
    end
end

nyi("exec")
nyi("preprocess_element")
nyi("title")
nyi("footnotes")
nyi("toc")
nyi("breadcrumbs")
nyi("wrap")
nyi("relative_links")
nyi("absolute_links")

return plugins
