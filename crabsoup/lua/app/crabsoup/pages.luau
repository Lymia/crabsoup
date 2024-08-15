local module = {}

local function build_globals(config, page_file)
    return {
        page = nil,
        page_file = page_file,
    }
end

local warned_extensions = {}
function module.process_page(config, page_file)
    local globals = build_globals(config, page_file)

    local extension = Sys.get_extension(page_file)
    local processor = config.raw.parsed.preprocessors[extension]

    local page
    if not processor then
        if not warned_extensions[extension] and extension ~= "htm" and extension ~= "html" then
            warned_extensions[extension] = true
            Log.warn("Extension '.{extension}' has no preprocessor defined. It will be treated as a HTML document.")
        end
        page = HTML.parse(Sys.read_file(page_file))
    else
        local raw_cmd = table.clone(processor)
        if raw_cmd.shell then
            raw_cmd.shell = `{raw_cmd.shell} "{page_file}"`
            Log.trace(`Run preprocessor: {raw_cmd.shell}`)
        else
            table.insert(raw_cmd, page_file)
            Log.trace(`Run preprocessor: {Value.repr_compact(raw_cmd)}`)
        end
        raw_cmd.capture_stdout = true

        local command = Process.spawn(raw_cmd)
        local finished_command = Process.wait_on_yield(command)
        Process.check_status(finished_command)
        page = HTML.parse(Process.get_stdout(finished_command))
    end

    return HTML.to_string(page)
end

return module
