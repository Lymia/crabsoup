local config = require("crabsoup.config")
local plugins = require("crabsoup.plugins")
local widget = require("crabsoup.widget")

type Configuration = {
    raw_configuration: any,
    plugin_manager: any,
    widget_list: { any },
}

local module = {}

function module.init_from_configuration(toml_file): Configuration
    -- load and parse configurations
    Log.info("Loading configuration and plugins...")
    local config = config.load_configuration(Sys.read_file(toml_file))

    -- load plugins
    local plugin_manager = plugins.create_plugin_manager("")
    plugin_manager:register_plugin_from_toml(config)

    -- load widgets
    local widget_list = widget.load_widgets(plugin_manager, config)

    return {
        raw_configuration = config,
        plugin_manager = plugin_manager,
        widget_list = widget_list,
    }
end

return module