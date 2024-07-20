--!strict

local builtin_funcs, _G = ...

-- Function definitions for `String` module
local String = _G.String or {}
_G.String = String

function String.is_valid_utf8(str: string): boolean
    if utf8.len(str) then
        return true
    else
        return false
    end
end

function String.length(str: string): number
    local len = utf8.len(str)
    return if len then len else #str
end

function String.length_ascii(str: string): number
    return #str
end

String.trim = string.trim

String.to_number = tonumber

function String.join(sep: string, list: {string}): string
    return table.concat(list, sep)
end

String.ends_with = string.endswith
String.starts_with = string.startswith

-- Function definitions for `Table` module
local Table = _G.Table or {}
_G.Table = Table

function Table.has_key(table, key)
    if table[key] == nil then
        return nil
    else
        return true
    end
end
