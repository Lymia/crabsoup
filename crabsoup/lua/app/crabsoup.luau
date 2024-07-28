local module = {}

local plugins = require("plugins")

function module.main(args)
    Log.info(`crabsoup v{Plugin.crabsoup_version()} (compatible: Soupault v{Plugin.soupault_version()})`)
    Log.info("Starting website generation...")

    local config = TOML.from_string(Sys.read_file("soupault.toml"))
    print(Value.repr(config))

    local plugin_manager = plugins.create_plugin_manager("")
    plugin_manager:register_plugins_from_dir("plugins")
end

return module
