--!strict
--!native

local shared, _G = ...

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
