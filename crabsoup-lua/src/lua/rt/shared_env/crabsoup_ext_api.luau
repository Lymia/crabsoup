--!strict

local builtin_funcs, _G = ...
local crabsoup = builtin_funcs.crabsoup

-- Extensions to the Plugin module
function _G.Plugin.crabsoup_version(): string
    return crabsoup.VERSION_ONLY
end
