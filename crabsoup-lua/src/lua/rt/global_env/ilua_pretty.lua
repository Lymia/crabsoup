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

--
-- Pretty print / format class
--

local Pretty = {}
builtin_funcs.Pretty = Pretty

Pretty.defaults = {
    items = 100, -- max number of items to list in one table
    depth = 7, -- max recursion depth when printing tables
    len = 80, -- max line length hint
    indent_count = 4, -- number of spaces to indent with

    function_info = false, -- show the function info (similar to table_info)
    multiline = true, -- set to false to disable multiline output
}

Pretty.__call = function(self, ...)
    self:print(...)
end

function Pretty:new(params)
    local obj = {}
    params = params or {}
    setmetatable(obj, self)
    self.__index = self
    obj:init(params)
    return obj
end

function Pretty:init(params)
    for k, v in pairs(self.defaults) do
        self[k] = v
    end
    for k, v in pairs(params) do
        self[k] = v
    end
    self.print_handlers = self.print_handlers or {}
    self:reset_seen()
end

function Pretty:reset_seen()
    self.seen = {}
    setmetatable(self.seen, { __do_not_enter = "<< ! >>" })
end

function Pretty:val2str(val, path, depth, multiline)
    local tp = type(val)
    if self.print_handlers[tp] then
        local s = self.print_handlers[tp](val)
        return s or '?'
    end
    if tp == 'function' then
        return self.function_info and tostring(val) or "function"
    elseif tp == 'table' then
        local mt = getmetatable(val)
        if mt and mt.__do_not_enter then
            return mt.__do_not_enter
        elseif mt and mt.__tostring then
            return tostring(val)
        else
            return self:table2str(val, path, depth, multiline)
        end
    elseif tp == 'string' then
        return escape_string(val)
    elseif tp == 'number' then
        -- we try only to apply floating-point precision for numbers deemed to be floating-point,
        -- unless the 3rd arg to precision() is true.
        if self.num_prec and (self.num_all or math.floor(val) ~= val) then
            return string.format(self.num_prec, val)
        else
            return tostring(val)
        end
    else
        return tostring(val)
    end
end

function Pretty:table2str(tbl, path, depth, multiline)
    -- don't print tables we've seen before
    for p, t in pairs(self.seen) do
        if tbl == t then
            return string.format("<< %s >>", p)
        end
    end
    -- max_depth
    self.seen[path] = tbl
    if depth >= self.depth then
        return ">>>"
    end
    return self:table_children2str(tbl, path, depth, multiline)
end

function Pretty:table_children2str(tbl, path, depth, multiline)
    local ind1, ind2 = indent(depth * self.indent_count), indent((depth + 1) * self.indent_count)

    local bl, br, empty = "{ ", " }", "{ }" -- table braces, single line mode
    local bl_m, br_m = "{\n", "\n" .. ind1 .. "}" -- table braces, multiline mode
    local sep = ", " -- the seperator used between table entries
    local eol = "\n" -- end of line (multiline)
    local eq = " = " -- table equals string value (printed as key..eq..value)

    local compactable, cnt, c = 0, 0, {}

    -- metatable
    local mt = getmetatable(tbl)
    if mt then
        local meta_str = self:val2str(mt, path .. (path == "" and "" or ".") .. "<metatable>", depth + 1, multiline)
        table.insert(c, "<metatable>" .. self.eq .. meta_str)
    end

    -- process child nodes, sorted
    local last = nil
    for k, v in pairs_by_keys(tbl, self.sort_function) do
        -- item limit
        if self.items and cnt >= self.items then
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
        local val = self:val2str(v,
                path .. (path == "" and "" or ".") .. key, depth + 1, multiline)
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
            local f = v .. (i == cnt and "" or sep)
            if line == "" then
                line = ind2 .. f
            elseif #line + #f <= self.len then
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
            table.insert(c2, ind2 .. v .. (i == cnt and "" or sep))
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

function Pretty:format(...)
    local out, v = "", nil
    -- first try single line output
    self:reset_seen()
    for i = 1, select("#", ...) do
        v = select(i, ...)
        out = string.format("%s%s ", out, self:val2str(v, "", 0, false))
    end
    -- if it is too long, use multiline mode, if enabled
    if self.multiline and #out > self.len then
        out = ""
        self:reset_seen()
        for i = 1, select("#", ...) do
            v = select(i, ...)
            out = string.format("%s%s\n", out, self:val2str(v, "", 0, true))
        end
    end
    self:reset_seen()
    return string.trim(out)
end

function Pretty:print(...)
    local output = self:format(...)
    if self.output_handler then
        self.output_handler(output)
    else
        if output and output ~= "" then
            print(output)
        end
    end
end

local pretty_instance = Pretty:new()
function builtin_funcs.repr(a)
    return pretty_instance:format(a)
end
