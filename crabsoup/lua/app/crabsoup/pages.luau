--!strict

local template = require("crabsoup.template")
local utils = require("crabsoup.utils")
local widget = require("crabsoup.widget")

local module = {}

local function build_globals(config, source_path, target_path): any
    local relative_prefix = config.raw.parsed.settings.site_dir
    while string.endswith(relative_prefix, "/") do
        relative_prefix = string.sub(relative_prefix, 1, #relative_prefix - 1)
    end
    local len = #relative_prefix
    relative_prefix ..= "/"

    assert(string.startswith(source_path, relative_prefix), "Internal error: could not build relative_page_file")

    return {
        page = nil, -- Set by process_page
        page_file = source_path,
        target_dir = `{Sys.dirname(target_path)}/`,
        target_file = target_path,
        nav_path = {}, -- TODO
        page_url = "", -- TODO
        config = nil, -- Set by widget module
        soupault_config = config.raw.raw,
        site_index = {}, -- TODO
        index_entry = nil, -- TODO
        site_dir = config.raw.parsed.settings.site_dir,
        build_dir = config.raw.parsed.settings.build_dir,
        persistent_data = {}, -- Set by widget module
        global_data = {}, -- TODO
        soupault_pass = 0, -- TODO

        -- Crabsoup extensions
        relative_page_file = string.sub(source_path, #relative_prefix + 1),
        global_config = config.raw.raw,
        parsed_config = config.raw.parsed,
    }
end

local warned_extensions = {}
function module.process_page(config, source_path, target_path)
    local extension = Sys.get_extension(source_path)
    local processor = config.raw.parsed.preprocessors[extension]

    -- Create globals
    local globals = build_globals(config, source_path, target_path)

    -- Load and preprocess page
    local page
    if not processor then
        if not warned_extensions[extension] and extension ~= "htm" and extension ~= "html" then
            warned_extensions[extension] = true
            Log.warn("Extension '.{extension}' has no preprocessor defined. It will be treated as a HTML document.")
        end
        page = HTML.parse(Sys.read_file(source_path))
    else
        local raw_cmd = table.clone(processor) :: any
        if raw_cmd.shell then
            raw_cmd.shell = `{raw_cmd.shell} "{source_path}"`
            Log.trace(`Run preprocessor: {raw_cmd.shell}`)
        else
            table.insert(raw_cmd, source_path)
            Log.trace(`Run preprocessor: {Value.repr_compact(raw_cmd)}`)
        end
        raw_cmd.capture_stdout = true
        utils.env_from_globals(raw_cmd, globals)

        local command = Process.spawn(raw_cmd)
        local finished_command = Process.wait_on_yield(command)
        Process.check_status(finished_command)
        page = HTML.parse(Process.get_stdout(finished_command))
    end
    globals.page = page

    -- Apply template
    template.apply_template(config.templates, globals)

    -- Apply plugins
    widget.run_widgets(config.widget_list, globals)

    return HTML.pretty_print(globals.page)
end

return module
