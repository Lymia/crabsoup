--!strict

local module = {}

local init = require("crabsoup.init")

function module.main(args)
    Log.info(`crabsoup v{Plugin.crabsoup_version()} (compatible: Soupault v{Plugin.soupault_version()})`)

    local config = init.init_from_configuration("soupault.toml")
    init.process_pages(config)
end

return module
