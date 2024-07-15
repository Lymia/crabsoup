--
-- ilua_pretty.lua
--
-- The pretty printing library from ilua
--
-- Steve Donovan, 2007
-- Chris Hixon, 2010
-- Alissa Rao, 2024
--

local builtin_funcs = ...

-- local vars
local identifier = "^[_%a][_%w]*$"

-- encodes a string as you would write it in code,
-- escaping control and other special characters
local function escape_char(c)
    return string.format("\\%03d", string.byte(c))
end
local function escape_string(str)
    local es_repl = {
        ["\0"] = "\\0",
        ["\a"] = "\\a",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
        ["\v"] = "\\v",
        ["\\"] = "\\\\",
        ['"'] = '\\"',
    }

    str = string.gsub(str, '(["\0\a\b\f\n\r\n\t\v\\])', es_repl)
    str = string.gsub(str, "(%c)", escape_char)
    if not utf8.len(str) then
        -- escape invalid UTF-8 characters
        str = string.gsub(str, "([\128-\255])", escape_char)
    end
    return '"' .. str .. '"'
end

-- this sort function compares table keys to allow a sort by key
-- the order is: numeric keys, string keys, other keys(converted to string)
local function key_cmp(a, b)
    local at = type(a)
    local bt = type(b)
    if at == "number" then
        if bt == "number" then
            return a < b
        else
            return true
        end
    elseif at == "string" then
        if bt == "string" then
            return a < b
        elseif bt == "number" then
            return false
        else
            return true
        end
    else
        if bt == "string" or bt == "number" then
            return false
        else
            return tostring(a) < tostring(b)
        end
    end
end

-- returns an iterator to sort by table keys using func
-- as the comparison func. defaults to Pretty.key_cmp
local function pairs_by_keys(tbl, func)
    func = func or key_cmp
    local a = {}
    for n in pairs(tbl) do
        a[#a + 1] = n
    end
    table.sort(a, func)

    local i = 0
    return function()
        -- iterator function
        i = i + 1
        return a[i], tbl[a[i]]
    end
end

-- returns a string containing a given number of spaces
local cached_indent = {}
local function indent(count)
    if cached_indent[count] then
        return cached_indent[count]
    else
        local result = string.rep(" ", count)
        if count <= 50 then
            cached_indent[count] = result
        end
        return result
    end
end

-- Returns a string for a given function
local builtin_function_names = {}
local function fn2str(func)
    if typeof(func) ~= "function" then
        error("fn2str requires a function")
    end

    if builtin_function_names[func] then
        return builtin_function_names[func]
    end

    return tostring(func)
end
function builtin_funcs.register_builtin_name(func, name)
    builtin_function_names[func] = name
end

--
-- Pretty printer configuration
--
local max_items = 100 -- max number of items to list in one table
local max_depth = 7 -- max recursion depth when printing tables
local line_len = 120 -- max line length hint
local indent_len = 4 -- number of spaces to indent with

--
-- Pretty printer for various types
--
local table2str, table_children2str

local function val2str(val, path, depth, multiline, seen)
    local tp = typeof(val)

    if tp == 'function' then
        return fn2str(val)
    elseif tp == 'table' then
        local mt = getmetatable(val)
        if mt and mt.__do_not_enter then
            return mt.__do_not_enter
        elseif mt and mt.__tostring then
            return tostring(val)
        else
            return table2str(val, path, depth, multiline, seen)
        end
    elseif tp == 'string' then
        return escape_string(val)
    else
        return tostring(val)
    end
end

function table2str(tbl, path, depth, multiline, seen)
    -- don't print tables we've seen before
    if seen[tbl] then
        return "<recursion: " .. seen[tbl] .. ">"
    end
    seen[tbl] = path

    -- max_depth
    if depth >= max_depth then
        return ">>>"
    end
    return table_children2str(tbl, path, depth, multiline, seen)
end

function table_children2str(tbl, path, depth, multiline, seen)
    local ind1, ind2 = indent(depth * indent_len), indent((depth + 1) * indent_len)

    local bl, br, empty = "{ ", " }", "{ }" -- table braces, single line mode
    local bl_m, br_m = "{\n", "\n" .. ind1 .. "}" -- table braces, multiline mode
    local sep = ", " -- the seperator used between table entries
    local eol = "\n" -- end of line (multiline)
    local eq = " = " -- table equals string value (printed as key..eq..value)

    local compactable, cnt, c = 0, 0, {}

    -- metatable
    local mt = getmetatable(tbl)
    if mt then
        local meta_str = val2str(mt, path .. (path == "" and "" or ".") .. "<metatable>", depth + 1, multiline, seen)
        table.insert(c, "<metatable>" .. eq .. meta_str)
    end

    -- process child nodes, sorted
    local last = nil
    for k, v in pairs_by_keys(tbl) do
        -- item limit
        if cnt >= max_items then
            table.insert(c, "...")
            compactable = compactable + 1
            break
        end
        -- determine how to display the key. array part of table will show no keys
        local print_index = true
        local print_brackets = true
        if type(k) == "number" then
            if (last and k > 1 and k == last + 1) or (not last and k == 1) then
                print_index = false
                last = k
            else
                last = false
            end
        else
            last = nil
        end
        local key = tostring(k)
        if type(k) == "string" then
            if string.match(k, identifier) then
                print_brackets = false
            else
                key = escape_string(key)
            end
        end
        if print_brackets then
            key = '[' .. key .. ']'
        end
        -- format val
        local val = val2str(v, path .. (path == "" and "" or ".") .. key, depth + 1, multiline, seen)
        if not string.match(val, "[\r\n]") then
            compactable = compactable + 1
        end
        -- put the pieces together
        local out = ""
        if print_index then
            out = key .. eq .. val
        else
            out = val
        end
        table.insert(c, out)
        cnt = cnt + 1
    end

    -- compact
    if multiline and #c > 0 and compactable == #c then
        local lines = {}
        local line = ""
        for i, v in ipairs(c) do
            local f = v .. sep
            if line == "" then
                line = ind2 .. f
            elseif #line + #f <= line_len then
                line = line .. f
            else
                table.insert(lines, line)
                line = ind2 .. f
            end
        end
        table.insert(lines, line)
        return bl_m .. table.concat(lines, eol) .. br_m
    elseif #c == 0 then
        -- empty
        return empty
    elseif multiline then
        -- multiline
        local c2 = {}
        for i, v in ipairs(c) do
            table.insert(c2, ind2 .. v .. sep)
        end
        return bl_m .. table.concat(c2, eol) .. br_m
    else
        -- single line
        local c2 = {}
        for i, v in ipairs(c) do
            table.insert(c2, v .. (i == cnt and "" or sep))
        end
        return bl .. table.concat(c2) .. br
    end
end

local function format(multiline, ...)
    local out, v = "", nil
    local seen = {}

    -- first try single line output
    for i = 1, select("#", ...) do
        v = select(i, ...)
        out = string.format("%s%s ", out, val2str(v, "", 0, false, seen))
    end

    -- if it is too long, use multiline mode, if enabled
    if multiline and #out > line_len then
        out = ""
        seen = {}
        for i = 1, select("#", ...) do
            v = select(i, ...)
            out = string.format("%s%s\n", out, val2str(v, "", 0, true, seen))
        end
    end

    local result = string.trim(out)
    return result
end

function builtin_funcs.repr(...)
    return format(true, ...)
end
