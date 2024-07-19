--!strict

local builtin_funcs, _G = ...
local crabsoup = builtin_funcs.crabsoup

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

function String.slugify_soft(str: string): string
    return error("not yet implemented")
end

function String.slugify_ascii(str: string): string
    return error("not yet implemented")
end

function String.render_template(template_string: string, env: any): string
    return error("not yet implemented")
end

function String.base64_encode(string: string): string
    return error("not yet implemented")
end

function String.base64_decode(string: string): string
    return error("not yet implemented")
end

function String.url_encode(string: string, exclude: {string}?): string
    return error("not yet implemented")
end

function String.url_decode(string: string): string
    return error("not yet implemented")
end

-- TODO: Sys module

-- Function definitions for `Plugin` module
local Plugin = _G.Plugin or {}
_G.Plugin = Plugin

function Plugin.fail(message: any?): never
    coroutine.yield(crabsoup.plugin_fail(tostring(message)))
    return error("unreachable")
end

function Plugin.exit(message: any?): never
    coroutine.yield(crabsoup.plugin_exit(tostring(message)))
    return error("unreachable")
end

function Plugin.require_version(version: any?)
    error("not yet implemented")
end

function Plugin.soupault_version(): string
    return "4.10.0" -- Newest *compatible* version of Soupault.
end

-- TODO: Log module

-- TODO: JSON module

-- TODO: TOML module

-- TODO: YAML module

-- TODO: CSV module

-- TODO: Date module

-- TODO: Digest module

-- TODO: Table module

-- Function definitions for `Value` module
local Value = _G.Value or {}
_G.Value = Value

function Value.repr(value: any?): string
    local str = builtin_funcs.repr(value)
    return str
end

function Value.is_nil(value: any?): boolean
    return value == nil
end

function Value.is_int(value: any?): boolean
    if type(value) == "number" then
        return math.isfinite(value) and math.round(value) == value
    else
        return false
    end
end

function Value.is_float(value: any?): boolean
    return type(value) == "number"
end

function Value.is_string(value: any?): boolean
    return type(value) == "string"
end

function Value.is_table(value: any?): boolean
    return type(value) == "table"
end

function Value.is_list(value: any?): boolean
    if not value or type(value) ~= "table" then
        return false
    else
        for k in value do
            if type(k) ~= "number" then
                return false
            end
        end
        return true
    end
end

function Value.is_html(value: any?): boolean
    return typeof(value) == "NodeRef"
end
