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

--
-- local functions
--

-- function varsub(str, repl)
-- replaces variables in strings like "%20s{foo} %s{bar}" using the table repl
-- to look up replacements. use string:format patterns followed by {variable}
-- and pass the variables in a table like { foo="FOO", bar="BAR" }
-- variable names need to match Lua identifiers ([_%a][_%w]-)
-- missing variables or errors in formatting will result in empty strings
-- being inserted for the corresponding placeholder pattern
local function varsub(str, repl)
    return string.gsub(str, "(%%.-){([_%a][_%w]-)}", function(f, k)
        local r, ok = repl[k]
        ok, r = pcall(string.format, f, r)
        return ok and r or ""
    end)
end

-- encodes a string as you would write it in code,
-- escaping control and other special characters
local function escape_string(str)
    local es_repl = { ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
                      ["\\"] = "\\\\", ['"'] = '\\"' }
    str = string.gsub(str, '(["\r\n\t\\])', es_repl)
    str = string.gsub(str, "(%c)", function(c)
        return string.format("\\%d", string.byte(c))
    end)
    return string.format('"%s"', str)
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
    indent1 = "    ", -- string repeated each indent level
    indent2 = "    ", -- string used to indent final level
    indent3 = "    ", -- string used to indent final level continuation
    empty = "{ }", -- string used for empty table
    bl = "{ ", -- table braces, single line mode
    br = " }",
    bl_m = "{\n", -- table braces, multiline mode, substitution available:
    br_m = "\n%s{i}}", -- %s{i}, %s{i1}, %s{i2}, %s{i3} are calulated indents
    eol = "\n", -- end of line (multiline)
    sp = " ", -- used other places where spacing might be desired but optional
    eq = " = ", -- table equals string value (printed as key..eq..value)
    key = false, -- format of key in field (set to pattern to enable)
    value = false, -- format of value in field (set to pattern to enable)
    field = "%s", -- format of field (which is either "k=v" or "v", with delimiter)
    tstr = true, -- use to tostring(table) if table has meta __tostring
    table_info = false, -- show the table info (usually a hex address)
    function_info = false, -- show the function info (similar to table_info)
    multiline = true, -- set to false to disable multiline output
    compact = true, -- will compact leaf tables in multiline mode
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

function Pretty:table2str(tbl, path, depth, multiline)
    -- don't print tables we've seen before
    for p, t in pairs(self.seen) do
        if tbl == t then
            local tinfo = self.table_info and tostring(tbl) or p
            return string.format("<< %s >>", tinfo)
        end
    end
    -- max_depth
    self.seen[path] = tbl
    if depth >= self.depth then
        return ">>>"
    end
    return self:table_children2str(tbl, path, depth, multiline)
end

-- this sort function compares table keys to allow a sort by key
-- the order is: numeric keys, string keys, other keys(converted to string)
function Pretty.key_cmp(a, b)
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
function Pretty.pairs_by_keys(tbl, func)
    func = func or Pretty.key_cmp
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

function Pretty:table_children2str(tbl, path, depth, multiline)
    local sp, eol, eq = self.sp, self.eol, self.eq
    local bl, br = self.bl, self.br
    local bl_m, br_m = self.bl_m, self.br_m
    local tinfo = self.table_info and tostring(tbl) .. sp or ""
    local key_fmt, val_fmt, field = self.key, self.val, self.field
    local compactable, cnt, c = 0, 0, {}

    -- multiline setup
    local ind1, ind2, ind3 = "", "", ""
    if multiline then
        ind1 = string.rep(self.indent1, depth)
        ind2 = ind1 .. self.indent2
        ind3 = ind1 .. self.indent3
        local irepl = { i = ind1, i1 = ind1, i2 = ind2, i3 = ind3 }
        bl_m, br_m = varsub(bl_m, irepl), varsub(br_m, irepl)
    end

    -- metatable
    local mt = getmetatable(tbl)
    if mt then
        table.insert(c, "<metatable>" .. self.eq .. self:val2str(mt, path .. (path == "" and "" or ".") .. "<metatable>", depth + 1, multiline))
    end

    -- process child nodes, sorted
    local last = nil
    for k, v in Pretty.pairs_by_keys(tbl, self.sort_function) do
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
        if val_fmt then
            val = string.format(val_fmt, val)
        end
        -- put the pieces together
        local out = ""
        if key_fmt then
            key = string.format(key_fmt, key)
        end
        if print_index then
            out = key .. eq .. val
        else
            out = val
        end
        table.insert(c, out)
        cnt = cnt + 1
    end

    -- compact
    if multiline and self.compact and #c > 0 and compactable == #c then
        local lines = {}
        local line = ""
        for i, v in ipairs(c) do
            local f = string.format(field, v .. (i == cnt and "" or ", "))
            if line == "" then
                line = ind2 .. f
            elseif #line + #f <= self.len then
                line = line .. f
            else
                table.insert(lines, line)
                line = ind3 .. f
            end
        end
        table.insert(lines, line)
        return tinfo .. bl_m .. table.concat(lines, eol) .. br_m
    elseif #c == 0 then
        -- empty
        return tinfo .. self.empty
    elseif multiline then
        -- multiline
        local c2 = {}
        for i, v in ipairs(c) do
            table.insert(c2, ind2 .. string.format(field, v .. (i == cnt and "" or ", ")))
        end
        return tinfo .. bl_m .. table.concat(c2, eol) .. br_m
    else
        -- single line
        local c2 = {}
        for i, v in ipairs(c) do
            table.insert(c2, string.format(field, v .. (i == cnt and "" or ", ")))
        end
        return tinfo .. bl .. table.concat(c2) .. br
    end
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
        elseif self.tstr and mt and mt.__tostring then
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
