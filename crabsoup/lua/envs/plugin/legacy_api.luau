--!strict

local shared, _G = ...

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

-- Function definitions for 'HTML' module
local function join_selectors(selectors: any?): string
    if type(selectors) == "table" then
        return table.concat(selectors, ",")
    else
        error("selector list must be a table")
    end
end

function _G.HTML.select_any_of(node, list)
    return HTML.select_one(node, join_selectors(list))
end
function _G.HTML.select_all_of(node, list)
    return HTML.select(node, join_selectors(list))
end
function _G.HTML.matches_any_of_selectors(node, list)
    return HTML.matches_selector(node, join_selectors(list))
end

_G.HTML.append_root = HTML.append_child
_G.HTML.prepend_root = HTML.prepend_child
_G.HTML.replace = HTML.replace_element
