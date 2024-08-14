--!strict

local module = {}

local init = require("crabsoup.init")

function module.main(args)
    Log.info(`crabsoup v{Plugin.crabsoup_version()} (compatible: Soupault v{Plugin.soupault_version()})`)

    local config = init.init_from_configuration("soupault.toml")
    print(Value.repr(config))
end

return module
