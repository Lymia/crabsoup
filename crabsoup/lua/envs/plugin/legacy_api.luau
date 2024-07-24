--!strict

local shared, _G = ...

-- Helper functions
local function create_unsafe_from_string<T>(func: (string) -> T): (string) -> T?
    return function(str)
        local status, result = pcall(func, str)
        if status then
            return result
        else
            return nil
        end
    end
end

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

-- Function definitions for 'JSON' module
local JSON = _G.JSON or {}
_G.JSON = JSON

JSON.unsafe_from_string = create_unsafe_from_string(JSON.from_string)

-- Function definitions for 'TOML' module
local TOML = _G.TOML or {}
_G.TOML = TOML

TOML.unsafe_from_string = create_unsafe_from_string(TOML.from_string)

-- Function definitions for 'YAML' module
local YAML = _G.YAML or {}
_G.YAML = YAML

YAML.unsafe_from_string = create_unsafe_from_string(YAML.from_string)

-- Function definitions for 'YAML' module
local CSV = _G.CSV or {}
_G.CSV = CSV

CSV.unsafe_from_string = create_unsafe_from_string(CSV.from_string)

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

-- Function definitions for 'Sys' module
_G.Sys.get_file_modification_date = _G.Sys.get_file_modification_time

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

-- Function definitions for `Sys` module
local Sys = _G.Sys or {}
_G.Sys = Sys

function Sys.random(n)
    return math.random(0, n)
end
