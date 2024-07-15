--!strict

local builtin_funcs, _G = ...
local crabsoup = builtin_funcs.crabsoup

-- Reimplement base library functions
local function loadstring(chunk: string, chunkname: string?, mode: string?, env: any?): (((...any) -> any)?, string?)
    if type(chunk) ~= "string" then
        return error("chunk must be a string")
    end
    if chunkname and type(chunkname) ~= "string" then
        return error("chunk name must be a string or nil")
    end
    if env and type(env) ~= "table" then
        return error("function environment must be a table or nil")
    end

    if mode then
       crabsoup.warn("`mode` is ignored on `loadstring` and `load`")
    end

    if not env then
       env = getfenv(2)
    end
    builtin_funcs.low_level.deoptimize_env(env)
    return crabsoup.loadstring(chunk, chunkname, env)
end

function _G.load(chunk: () -> string? | string, chunkname: string?, mode: string?, env: any?): (((...any) -> any)?, string?)
    local code
    if type(chunk) == "string" then
        code = chunk
    elseif type(chunk) == "function" then
        code = ""
        while true do
            local section = chunk()
            if section and #section > 0 then
                code += section
            else
                break
            end
        end
    else
        return error("Chunk function given to `load` must be a function or string.", 2)
    end
    if not env then
        env = getfenv(2)
    end
    return loadstring(code, chunkname, mode, env)
end

function _G.dofile(filename: string): any
    return error("not yet implemented", 2)
end

_G.loadstring = loadstring
