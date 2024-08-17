--!strict

local module = {}

local action_map: { [string]: (NodeRef, NodeRef) -> () } = {
    prepend = HTML.prepend,
    prepend_child = HTML.prepend,
    append = HTML.append,
    append_child = HTML.append_child,
    insert_before = HTML.insert_before,
    insert_after = HTML.insert_after,
    replace_content = HTML.replace_content,
    replace_element = HTML.replace_element,
}
function module.lookup_action(action_name: string): (NodeRef, NodeRef) -> ()
    local result = action_map[action_name]
    if not result then
        error(`Unknown content action: {action_name}`)
    end
    return result
end

local function matches_limits(pages, sections, path_regexes, include_subsections)
    local regexes = table.clone(path_regexes)

    for _, page in pages do
        table.insert(regexes, `^{Regex.escape(page)}`)
    end
    for _, section in sections do
        while string.startswith(section, "/") do
            section = string.sub(section, 2)
        end
        while string.endswith(section, "/") do
            section = string.sub(section, 1, #section - 1)
        end
        local tail = if include_subsections then "[^/]+" else ".*"
        table.insert(regexes, `^{Regex.escape(section)}/{tail}`)
    end

    return function(raw_path)
        return Table.for_any(function(x)
            return Regex.match(raw_path, x)
        end, regexes)
    end
end

function module.parse_limiting_options(value)
    local no_whitelist = Table.is_empty(value.page)
        and Table.is_empty(value.section)
        and Table.is_empty(value.path_regex)
    local include = matches_limits(value.page, value.section, value.path_regex, value.include_subsections)
    local exclude =
        matches_limits(value.exclude_page, value.exclude_section, value.exclude_path_regex, value.include_subsections)

    return function(globals)
        local path = globals.relative_page_file
        return (no_whitelist or include(path)) and not exclude(path)
    end
end

function module.env_from_globals(cmd, globals)
    cmd.env = {
        PAGE_FILE = globals.page_file,
        TARGET_DIR = globals.target_dir,
        TARGET_FILE = globals.target_file,
        SITE_DIR = globals.site_dir,
        BUILD_DIR = globals.build_dir,
        RELATIVE_PAGE_FILE = globals.relative_page_file,
        PAGE_URL = globals.page_url,
    }
end

function module.parse_toml_selector(value): string
    if not value then
        return "#xx:not(#xx)"
    elseif type(value) == "table" then
        return table.concat(value, ",")
    elseif type(value) == "string" then
        return value
    else
        return error("'selector' is neither a list of strings nor a string")
    end
end

function module.parse_command(value): { shell: string } | { string } | nil
    if not value then
        return nil
    elseif type(value) == "string" then
        return { shell = value }
    elseif type(value) == "table" then
        for k, v in value do
            if type(k) ~= "number" then
                return error("'command' should be a list, not a dictionary")
            end
            if type(v) ~= "string" then
                return error("'command' should be a list of strings")
            end
        end
        return value
    else
        return error("'command' is neither a list of strings nor a string")
    end
end

return module
