--!strict

local builtin_funcs = ...
local crabsoup = builtin_funcs.crabsoup

-- Stored stdlib functions
local getfenv = getfenv

-- Extensions to the Plugin module
function _G.Plugin.crabsoup_version(): string
    return crabsoup.VERSION_ONLY
end

function _G.Plugin.repl_interrupt()
    local env = getfenv(2)
    builtin_funcs.run_repl_in_env(env)
end
