--!strict

local shared, _G = ...
local baselib = shared.baselib

-- Function definitions for `String` module
local String = _G.String or {}
_G.String = String

function String.truncate(str: string, length: number, trailer: string?): string
    local len = utf8.len(str)
    if len then
        if len == length then
            return str
        else
            local offset = utf8.offset(str, length)
            if offset >= #str then
                return str
            else
                return string.sub(str, 0, offset) .. (trailer or "")
            end
        end
    elseif length >= #str then
        return str
    else
        return string.sub(str, 0, length) .. (trailer or "")
    end
end

-- Function definitions for `Sys` module
local Sys = _G.Sys or {}
_G.Sys = Sys

Sys.basename_url = Sys.basename_unix
Sys.dirname_url = Sys.dirname_unix
Sys.join_url = Sys.join_path_unix
Sys.split_path_url = Sys.split_path_unix

-- Function definitions for `Plugin` module
local Plugin = _G.Plugin or {}
_G.Plugin = Plugin

function Plugin.fail<T>(message: T): never
    coroutine.yield(baselib.plugin_fail(tostring(message)))
    return error("Coroutine resumed despite Plugin.fail?")
end

function Plugin.exit<T>(message: T): never
    coroutine.yield(baselib.plugin_exit(tostring(message)))
    return error("Coroutine resumed despite Plugin.exit?")
end

local supported_soupault_version = "4.10.0" -- Newest *compatible* version of Soupault.
local crabsoup_version = shared.baselib.VERSION_ONLY

function Plugin.require_version(version: string)
    local min_components = string.split(version, ".")
    local cur_components = string.split(supported_soupault_version, ".")

    for i = 1, math.max(#min_components, #cur_components) do
        local min = tonumber(min_components[i] or "0") or error("could not parse number")
        local cur = tonumber(cur_components[i] or "0") or error("could not parse number")
        if cur > min then
            return
        end
        if min > cur then
            error(
                `Plugin requires Soupault v{version} compatibility, but crabsoup v{crabsoup_version} is compatible with Soupault v{supported_soupault_version}.`,
                2
            )
        end
    end
end

function Plugin.soupault_version(): string
    return supported_soupault_version
end

function Plugin.crabsoup_version(): string
    return crabsoup_version
end

-- Function definitions for `Log` module
local Log = _G.Log or {}
_G.Log = Log

Log.trace = baselib.trace
Log.debug = baselib.debug
Log.info = baselib.info
Log.warn = baselib.warn
Log.warning = baselib.warn
Log.error = baselib.error

-- Function definitions for `Date` module
local Date = _G.Date or {}
_G.Date = Date

function _G.Date.now_format(fmt, tz)
    return Date.format(Date.now_timestamp(), fmt, tz)
end
function _G.Date.reformat(date, inputs, fmt, tz)
    return Date.format(Date.to_timestamp(date, inputs, tz), fmt)
end

-- Function definitions for the `Table` module
local Table = _G.Table or {}
_G.Table = Table

function Table.get_key_default<K, V>(table: { [K]: V }, key: K, default_value: V): V
    if table[key] == nil then
        table[key] = default_value
    end
    return table[key]
end

function Table.keys<K, V>(value: { [K]: V }): { K }
    local new_table = {}
    for k, _ in value do
        table.insert(new_table, k)
    end
    return new_table
end

function Table.has_value<K, V>(table: { [K]: V }, value: V): boolean
    for _, v in table do
        if v == value then
            return true
        end
    end
    return false
end

function Table.iter<K, V>(func: (K, V) -> (), table: { [K]: V })
    for k, v in table do
        func(k, v)
    end
end
function Table.iter_values<K, V>(func: (V) -> (), table: { [K]: V })
    for _, v in table do
        func(v)
    end
end

local function compare_any(a: any?, b: any?): boolean
    local ta, tb = type(a), type(b)
    if ta < tb then
        return true
    elseif ta > tb then
        return false
    elseif type(a) == "string" and type(b) == "string" then
        return a < b
    elseif type(a) == "number" and type(b) == "number" then
        return a < b
    else
        return tostring(a) < tostring(b)
    end
end
function Table.iter_ordered<K, V>(func: (K, V) -> (), value: { [K]: V })
    local keys = Table.keys(value)
    table.sort(keys, compare_any)
    for _, k in keys do
        func(k, value[k])
    end
end
function Table.iter_values_ordered<K, V>(func: (V) -> (), value: { [K]: V })
    local keys = Table.keys(value)
    table.sort(keys, compare_any)
    for _, k in keys do
        func(value[k])
    end
end

function Table.fold<K, V, A>(func: (K, V, A) -> A, value: { [K]: V }, initial_value: A): A
    local accum = initial_value
    for k, v in value do
        accum = func(k, v, accum)
    end
    return accum
end
function Table.fold_values<K, V, A>(func: (V, A) -> A, value: { [K]: V }, initial_value: A): A
    local accum = initial_value
    for _, v in value do
        accum = func(v, accum)
    end
    return accum
end

function Table.map<K, V, R>(func: (K, V) -> R, value: { [K]: V }): { [K]: R }
    local out = {}
    for k, v in value do
        out[k] = func(k, v)
    end
    return out
end
function Table.map_values<K, V, R>(func: (V) -> R, value: { [K]: V }): { [K]: R }
    local out = {}
    for k, v in value do
        out[k] = func(v)
    end
    return out
end

function Table.filter_map<K, V>(func: (K, V) -> boolean, value: { [K]: V }): { [K]: V }
    local out = {}
    for k, v in value do
        if func(k, v) then
            out[k] = v
        end
    end
    return out
end
function Table.filter_list<V>(func: (V) -> boolean, value: { V }): { V }
    local out = {}
    for k, v in value do
        if func(v) then
            table.insert(out, v)
        end
    end
    return out
end

function Table.apply<K, V>(func: (K, V) -> V, value: { [K]: V })
    for k, v in value do
        value[k] = func(k, v)
    end
end
function Table.apply_to_values<K, V>(func: (V) -> V, value: { [K]: V })
    for k, v in value do
        value[k] = func(v)
    end
end

function Table.for_all<K, V>(func: (V) -> boolean, table: { [K]: V }): boolean
    for _, v in table do
        if not func(v) then
            return false
        end
    end
    return true
end
function Table.for_any<K, V>(func: (V) -> boolean, table: { [K]: V }): boolean
    for _, v in table do
        if func(v) then
            return true
        end
    end
    return false
end

function Table.take<T>(value: { T }, count: number): { T }
    local out = {}
    for i = 1, count do
        out[i] = value[i]
    end
    for i = count + 1, #value do
        value[i - count] = value[i]
    end
    for i = #value - count, #value do
        value[i] = nil
    end
    return out
end

function Table.chunks<T>(value: { T }, size: number): { { T } }
    local chunks = {}
    local current = {}
    for i = 1, #value do
        table.insert(current, value[i])

        if #current == size then
            table.insert(chunks, current)
            current = {}
        end
    end
    if #current > 1 then
        table.insert(chunks, current)
    end
    return chunks
end

function Table.length<K, V>(value: { [K]: V }): number
    local count = 0
    for _ in value do
        count += 1
    end
    return count
end

function Table.is_empty<K, V>(value: { [K]: V }): boolean
    for _ in value do
        return false
    end
    return true
end

local function deep_clone(value)
    local new = {}
    for k, v in value do
        if type(v) == "table" then
            new[k] = deep_clone(v)
        else
            new[k] = v
        end
    end
    return new
end
Table.deep_clone = deep_clone

-- Function definitions for `Value` module
local Value = _G.Value or {}
_G.Value = Value

function Value.repr<T>(value: T): string
    local str = shared.repr(value)
    return str
end

function Value.repr_compact<T>(value: T): string
    local str = shared.repr_compact(value)
    return str
end

-- Function definitions for `Process` module
local Process = _G.Process or {}
_G.Process = Process

function Process.wait_on_yield(value: Process): CompletedProcess
    Process.is_completed(value) -- ignore value, this just checks several useful things
    local result = coroutine.yield(value)
    if typeof(result) ~= "CompletedProcess" then
        error("`coroutine.yield` did not return CompletedProcess!?")
    end
    return result
end
