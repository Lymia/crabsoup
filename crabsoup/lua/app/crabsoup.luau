--!strict

local module = {}

local config = require("config")
local plugins = require("plugins")

function module.main(args)
    Log.info(`crabsoup v{Plugin.crabsoup_version()} (compatible: Soupault v{Plugin.soupault_version()})`)

    Log.info("Loading configuration and plugins...")
    local config = config.load_configuration(Sys.read_file("soupault.toml"))
    Log.debug(Value.repr(config))

    local plugin_manager = plugins.create_plugin_manager("")
    plugin_manager:register_plugin_from_toml(config)
end

return module
