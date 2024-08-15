--!strict

local module = {}

local function build_globals(config, source_path, target_path): any
    return {
        page = nil, -- Set by process_page
        page_file = source_path,
        target_dir = `{Sys.dirname(target_path)}/`,
        target_file = target_path,
        nav_path = {}, -- TODO
        page_url = "", -- TODO
        config = nil, -- Set by widget module
        soupault_config = config.raw,
        site_index = nil, -- TODO
        index_entry = nil, -- TODO
        site_dir = config.raw.parsed.settings.site_dir,
        build_dir = config.raw.parsed.settings.build_dir,
        persistent_data = {}, -- Set by widget module
        global_data = {}, -- TODO
        soupault_pass = 0, -- TODO
        global_config = config.raw.raw,
        parsed_config = config.raw.parsed,
    }
end

local warned_extensions = {}
function module.process_page(config, source_path, target_path)
    local extension = Sys.get_extension(source_path)
    local processor = config.raw.parsed.preprocessors[extension]

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

        local command = Process.spawn(raw_cmd)
        local finished_command = Process.wait_on_yield(command)
        Process.check_status(finished_command)
        page = HTML.parse(Process.get_stdout(finished_command))
    end


    local globals = build_globals(config, source_path, target_path)
    globals.page = page

    return HTML.to_string(globals.page)
end

return module
