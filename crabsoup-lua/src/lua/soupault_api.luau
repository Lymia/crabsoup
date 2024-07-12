-- Stored stdlib functions
local error = error
local string_gsub = string.gsub
local string_sub = string.sub
local table_concat = table.concat
local type = type
local typeof = typeof
local utf8_len = utf8.len
local utf8_offset = utf8.offset

-- Function definitions for `String` module
local String = {}

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

function String.trim(str: string): string
    return string_gsub(str, "^%s*(.-)%s*$", "%1")
end

function String.truncate(str: string, length: number): string
    local len = utf8_len(str)
    if len then
        if len == length then
            return str
        else
            return string_sub(str, 0, utf8_offset(str, length))
        end
    else
        return string_sub(str, 0, length)
    end
end

function String.slugify_soft(str: string): string
    return error("not yet implemented")
end

function String.slugify_ascii(str: string): string
    return error("not yet implemented")
end

String.to_number = tonumber

function String.join(sep: string, list: {string}): string
    return table_concat(list, sep)
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

function String.url_encode(string: string): string
    return error("not yet implemented")
end

function String.url_decode(string: string): string
    return error("not yet implemented")
end

function String.startswith(str: string, start: string): boolean
    return start == "" or string_sub(str, 1, #start) == start
end

function String.endswith(str: string, ending: string): boolean
    return ending == "" or string_sub(str, -#ending) == ending
end

_G.String = table.freeze(String)

-- TODO: Sys module

-- TODO: Plugin module

-- TODO: Log module

-- TODO: JSON module

-- TODO: TOML module

-- TODO: YAML module

-- TODO: CSV module

-- TODO: Date module

-- TODO: Digest module

-- TODO: Table module

-- Function definitions for `Value` module
local Value = {}

Value.repr = tostring

function Value.is_nil(value: any): boolean
    return value == nil
end

function Value.is_int(value: any): boolean
    return type(value) == "number" and math.round(value) == value
end

function Value.is_float(value: any): boolean
    return type(value) == "number"
end

function Value.is_string(value: any): boolean
    return type(value) == "string"
end

function Value.is_table(value: any): boolean
    return type(value) == "table"
end

function Value.is_list(value: any): boolean
    if type(value) ~= "table" then
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

function Value.is_html(value: any): boolean
    return typeof(value) == "HtmlNode"
end

_G.Value = table.freeze(Value)