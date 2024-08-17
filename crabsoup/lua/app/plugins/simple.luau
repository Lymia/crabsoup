--!strict

local utils = require("crabsoup.utils")

local plugins = {} :: { [string]: (any) -> () }

local function nyi(name)
    plugins[name] = function(globals)
        Log.error(`Built-in widget '{name}' is not yet implemented!`)
    end
end

local function require_param(globals, param, plugin)
    if not globals.config[param] then
        Plugin.fail(`{plugin} plugin requires a '{param}' parameter to be given`)
    end
end

local function parse_html(globals, contents)
    if globals.config.parse == nil or globals.config.parse then
        return HTML.parse_fragment(contents, globals.config.fragment_root or "main")
    else
        return HTML.create_text(contents)
    end
end

local function insert_by_selector(globals, data, plugin)
    require_param(globals, "selector", plugin)

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
    require_param(globals, "file", "include")

    -- Read and parse the input file
    local data = parse_html(globals, Sys.read_file(globals.config.file))

    -- Insert the template into every matching selector
    insert_by_selector(globals, data, "include")
end

--
-- `insert_html` plugin
--
-- params: html, selector, parse, fragment_root
--
function plugins.insert_html(globals)
    -- Check parameters
    require_param(globals, "html", "insert_html")

    -- Read and parse the HTML
    local data = parse_html(globals, globals.config.html)

    -- Insert the template into every matching selector
    insert_by_selector(globals, data, "insert_html")
end

--
-- `exec` plugin
--
-- params: command, selector, parse, action, fragment_root
--
function plugins.exec(globals)
    -- Check parameters
    require_param(globals, "command", "exec")

    -- Read and parse the input file
    local cmd = utils.parse_command(globals.config.command)
    cmd.capture_stdout = true
    utils.env_from_globals(cmd, globals)

    local process = Process.wait_on_yield(Process.spawn(cmd))
    Process.check_status(process)
    local data = parse_html(globals, Process.get_stdout(process))

    -- Insert the template into every matching selector
    insert_by_selector(globals, data, "exec")
end

--
-- `preprocess_element` plugin
--
-- params: command, selector, parse, decode_entities, fragment_root
--
function plugins.preprocess_element(globals)
    -- Check parameters
    require_param(globals, "command", "preprocess_element")
    require_param(globals, "selector", "preprocess_element")

    -- Find all matching selectors.
    local action = utils.lookup_action(globals.config.action or "replace_content")
    local selector = utils.parse_toml_selector(globals.config.selector)

    Table.iter_values(function(elem)
        -- Retrieve and (possibly) decode HTML
        local input = HTML.inner_html(elem)
        if globals.config.decode_entities == nil or globals.config.decode_entities then
            if globals.config.decode_entities == nil then
                local has_tags = string.find(input, "<") or string.find(input, ">")
                local has_tag_entity = string.find(input, "&lt;") or string.find(input, "&gt;")

                if has_tags and has_tag_entity then
                    Log.warn(
                        `Widget '{globals.config.widget_name}' is configured to decode HTML entities in elements that \
                        contain &lt; or &gt; elements mixed with HTML tags. This creates ambiguities. Check your output!`
                    )
                    Log.warn("To silence this, manually set `decode_entities = true`.")
                end
            end

            input = String.html_decode(input)
        end

        -- Process the input
        local cmd = utils.parse_command(globals.config.command)
        cmd.capture_stdout = true
        cmd.stdin = input
        utils.env_from_globals(cmd, globals)

        cmd.env.TAG_NAME = HTML.get_tag_name(elem)
        for _, attr in HTML.list_attributes(elem) do
            local env_name = `ATTR_{string.upper(attr)}`
            cmd.env[env_name] = HTML.get_attribute(elem, attr)
        end

        local process = Process.wait_on_yield(Process.spawn(cmd))
        Process.check_status(process)
        local data = parse_html(globals, Process.get_stdout(process))

        -- Set the output into the element
        action(elem, data)
    end, HTML.select(globals.page, selector))
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

--
-- `title` plugin
--
-- params: selector, default, append, prepend, force, keep
--
function plugins.title(globals)
    require_param(globals, "selector", "title")

    -- Find the title tag
    local preexisting_title = HTML.select_one(globals.page, "title")
    if preexisting_title and string.trim(HTML.inner_text(preexisting_title)) ~= "" then
        if globals.config.keep == nil or globals.config.keep then
            return
        end
    end
    if not preexisting_title then
        if not globals.config.force then
            return
        end

        local head = HTML.select_one(globals.page, "head")
        if not head then
            Plugin.fail("No head element in page???")
        else
            local new_title = HTML.create_element("title")
            HTML.append_child(head, new_title)
            preexisting_title = new_title
        end
    end
    local title_elem = preexisting_title or error("unreachable??") -- for type checking only
    HTML.delete_content(title_elem)

    -- Find the page's title
    local selectors
    if type(globals.config.selector) == "string" then
        selectors = { globals.config.selector }
    elseif type(globals.config.selector) == "table" then
        for k, v in globals.config.selector do
            if type(k) ~= "number" then
                Plugin.fail("'selector' should be a list, not a dictionary")
            end
            if type(v) ~= "string" then
                Plugin.fail("'selector' should be a list of strings")
            end
        end
        selectors = globals.config.selector
    else
        Plugin.fail("'selector' should be a list of strings or a string")
    end

    local title = nil
    for _, selector in selectors do
        local first = HTML.select_one(globals.page, selector)
        if first then
            title = HTML.inner_text(first)
            break
        end
    end
    if not title then
        require_param(globals, "default", "title")
        title = tostring(globals.config.default)
    else
        if globals.config.append then
            title ..= tostring(globals.config.append)
        end
        if globals.config.prepend then
            title = tostring(globals.config.prepend) .. title
        end
    end

    -- Add the title to the <title> tag.
    HTML.append_child(title_elem, HTML.create_text(title))
end

nyi("footnotes")
nyi("breadcrumbs")
nyi("wrap")
nyi("relative_links")
nyi("absolute_links")

return plugins
