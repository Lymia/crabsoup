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

-- Remove setfenv/getfenv, as it deoptimizes luau, and I don't know to what scope
builtin_funcs.setfenv = _G.setfenv
builtin_funcs.getfenv = _G.getfenv

_G.setfenv = nil
_G.getfenv = nil