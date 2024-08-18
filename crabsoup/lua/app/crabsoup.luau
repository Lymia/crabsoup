--!strict

local module = {}

local init = require("crabsoup.init")

function module.main(args)
    Log.info(`crabsoup v{Plugin.crabsoup_version()} (compatible: Soupault v{Plugin.soupault_version()})`)

    print(Value.repr(args))

    local target = args.config
    if not target then
        if Sys.file_exists("crabsoup.toml") then
            target = "crabsoup.toml"
        elseif Sys.file_exists("soupault.toml") then
            target = "soupault.toml"
        else
            error("No configuration found.")
        end
    end

    local config = init.init_from_configuration(target)
    init.process_pages(config)
end

return module
