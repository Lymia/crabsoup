--!strict

local builtin_funcs, _G = ...
local crabsoup = builtin_funcs.crabsoup

-- Stored stdlib functions
local getfenv = getfenv
local string_gsub = string.gsub

-- Internal functions

function builtin_funcs.trim(str)
    return string_gsub(str, "^%s*(.-)%s*$", "%1")
end

-- Reimplement base library functions
local function loadstring(chunk: string, chunkname: string?, mode: string?, env: any?): (((...any) -> any)?, string?)
   if mode then
       crabsoup.warn("`mode` is ignored on `loadstring` and `load`")
   end
   if not env then
       env = getfenv(2)
   end
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
        error("Chunk function given to `load` must be a function or string.", 2)
    end
    if not env then
        env = getfenv(2)
    end
    return loadstring(code, chunkname, mode, env)
end

function _G.dofile(filename: string): any
    error("not yet implemented", 2)
    return nil
end

_G.loadstring = loadstring
