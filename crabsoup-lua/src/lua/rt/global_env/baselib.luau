--!strict

local builtin_funcs, _G = ...

-- imported global functions
local string_gsub = string.gsub
local string_sub = string.sub

-- Extensions to the standard string API
function _G.string.trim(str)
    return string_gsub(str, "^%s*(.-)%s*$", "%1")
end

function _G.string.startswith(str: string, start: string): boolean
    return start == "" or string_sub(str, 1, #start) == start
end

function _G.string.endswith(str: string, ending: string): boolean
    return ending == "" or string_sub(str, -#ending) == ending
end

-- Helper functions used by Rust code
function builtin_funcs.run_standalone(string, chunk_name)
    local env = builtin_funcs.envs.standalone
    local function loader(...)
        local chunk = builtin_funcs.crabsoup.loadstring(string, chunk_name)
        return chunk(...)
    end
    return builtin_funcs.low_level.load_in_new_thread(loader, env)
end
