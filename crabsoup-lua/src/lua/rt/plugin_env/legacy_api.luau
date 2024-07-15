--!strict

local builtin_funcs, _G = ...

-- Stored stdlib functions
local table_concat = table.concat
local utf8_len = utf8.len

-- Function definitions for `String` module
local String = _G.String or {}
_G.String = String

function String.is_valid_utf8(str: string): boolean
    if utf8_len(str) then
        return true
    else
        return false
    end
end

function String.length(str: string): number
    local len = utf8_len(str)
    return if len then len else #str
end

function String.length_ascii(str: string): number
    return #str
end

String.trim = string.trim

String.to_number = tonumber

function String.join(sep: string, list: {string}): string
    return table_concat(list, sep)
end

String.ends_with = string.endswith
String.starts_with = string.startswith
