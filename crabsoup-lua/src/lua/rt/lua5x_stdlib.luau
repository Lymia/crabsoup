local builtin_funcs = ...
local crabsoup = builtin_funcs.crabsoup

-- Stored stdlib functions
local getfenv = getfenv

-- Reimplement base library functions
function _G.loadstring(chunk, chunkname, mode, env)
    if mode then
        crabsoup.warn("`mode` is ignored on `loadstring` and `load`")
    end
    if not env then
        env = getfenv(2)
    end
    return crabsoup.loadstring(chunk, chunkname, env)
end
