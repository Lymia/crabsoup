--!strict

local config = require("crabsoup.config")
local pages = require("crabsoup.pages")
local plugins = require("crabsoup.plugins")
local scheduler = require("crabsoup.scheduler")
local template = require("crabsoup.template")
local widget = require("crabsoup.widget")

type Configuration = {
    raw: any,
    plugin_manager: any,
    widget_list: { any },
}

local module = {}

function module.init_from_configuration(toml_file): Configuration
    -- load and parse configurations
    Log.info("Loading configuration...")
    local config = config.load_configuration(Sys.read_file(toml_file))

    -- load plugins
    Log.info("Loading plugins...")
    local plugin_manager = plugins.create_plugin_manager("")
    plugin_manager:register_plugin_from_toml(config)

    -- load widgets
    Log.info("Loading widgets...")
    local widget_list = widget.load_widgets(plugin_manager, config)

    -- load templates
    Log.info("Loading templates...")
    local templates = template.parse_templates(config)

    -- return the full object
    return {
        raw = config,
        plugin_manager = plugin_manager,
        widget_list = widget_list,
        templates = templates,
    }
end

function module.process_pages(config: Configuration)
    Log.info("Preparing for website generation...")
    local extensions = {}
    for _, v in config.raw.parsed.settings.page_file_extensions do
        extensions[v] = true
    end

    local keep_extensions = {}
    for _, v in config.raw.parsed.settings.keep_extensions do
        keep_extensions[v] = true
    end

    Log.debug(`Recreate directory: '{config.raw.parsed.settings.build_dir}'`)
    Sys.delete_recursive(config.raw.parsed.settings.build_dir)
    Sys.mkdir(config.raw.parsed.settings.build_dir)

    Log.info("Starting website generation...")
    local dir_len = config.raw.parsed.settings.site_dir
    local thread_queue = {}
    for _, path in Sys.glob(`{config.raw.parsed.settings.site_dir}/**/*`) do
        local target_path = `{config.raw.parsed.settings.build_dir}/{string.sub(path, #dir_len + 2)}`

        if Sys.is_dir(path) then
            Log.debug(`Create directory: '{target_path}'`)
            Sys.mkdir(target_path)
        else
            if extensions[Sys.get_extension(path)] then
                -- process target path
                if not keep_extensions[Sys.get_extension(target_path)] then
                    local stripped = Sys.strip_extension(target_path)
                    target_path = `{stripped}.{config.raw.parsed.settings.default_extension}`
                end

                if Sys.file_exists(target_path) then
                    Log.error(`Skipping page (because it already exists): '{path}' -> '{target_path}'`)
                end

                -- enqueue the processor
                Log.trace(`Enqueue page: '{path}' -> '{target_path}'`)
                table.insert(thread_queue, {
                    name = path,
                    thread = function()
                        Log.debug(`Process page: '{path}' -> '{target_path}'`)
                        Sys.write_file(target_path, pages.process_page(config, path, target_path))
                    end,
                })
            else
                Log.debug(`Copy file: '{path}' -> '{target_path}'`)
                Sys.copy_file(path, target_path)
            end
        end
    end

    scheduler.wait_on_processes(thread_queue)
end

return module
