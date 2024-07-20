--!strict

local builtin_funcs, _G = ...

-- imported global functions
local debug_info = debug.info
local error = error
local math_isfinite = math.isfinite
local math_round = math.round
local string_gsub = string.gsub
local string_sub = string.sub

-- Globals
_G._CRABSOUP_VERSION = builtin_funcs.baselib._VERSION

-- Extensions to the standard string API
function _G.string.trim(str)
    return string_gsub(str, "^%s*(.-)%s*$", "%1")
end

function _G.string.startswith(str: string, start: string): boolean
    return start == "" or string_sub(str, 1, #start) == start
end

function _G.string.endswith(str: string, ending: string): boolean
    return ending == "" or string_sub(str, -#ending) == ending
end

-- Helper functions used by Rust code
function builtin_funcs.run_standalone(string, chunk_name)
    local env = builtin_funcs.envs.standalone
    local function loader(...)
        local chunk = builtin_funcs.baselib.loadstring(string, chunk_name)
        return chunk(...)
    end
    return builtin_funcs.low_level.load_in_new_thread(loader, env)
end

-- Extensions to the standard math API
_G.math.isnan = builtin_funcs.baselib.is_nan
_G.math.isinf = builtin_funcs.baselib.is_inf
_G.math.isfinite = builtin_funcs.baselib.is_finite

-- Sandboxed versions of setfenv and getfenv
builtin_funcs.orig_setfenv = _G.setfenv
builtin_funcs.orig_getfenv = _G.getfenv

_G.setfenv = nil
_G.getfenv = nil

local system_fenv = {}
function builtin_funcs.mark_system_fenv(env)
    system_fenv[env] = true
end

local function get_function_for_level(level: number): (...any) -> any
    if not math_isfinite(level) or math_round(level) ~= level then
        return error("numeric level must be an integer", 3)
    elseif level < 1 then
        return error("numeric level must be a positive integer", 4)
    else
        local real_level = level + 3
        local func = debug_info(real_level, "f")
        if not func then
            return error(`could not retrieve function for stack frame {level}`, 4)
        end
        return func
    end
end
local function retrieve_target(target: number | (...any) -> any | nil): (any?, (...any) -> any, string?)
    local target_out, result, source
    if not target or target == 0 then
        result = builtin_funcs.low_level.get_globals()
    else
        if type(target) == "number" then
            target_out = get_function_for_level(target)
            result = builtin_funcs.low_level.raw_getfenv(target_out)
            source = builtin_funcs.fn2str(target_out)
        elseif type(target) == "function" then
            target_out = target
            result = builtin_funcs.low_level.raw_getfenv(target)
            source = builtin_funcs.fn2str(target)
        else
            return error("target must be nil, a function or a number", 3)
        end
    end
    return target_out, result, source
end

function _G.getfenv(target: number | (...any) -> any | nil): any
    local _, result, source = retrieve_target(target)
    if system_fenv[result] then
        if not source then
            return error("cannot retrieve the global variables table for a protected context", 2)
        else
            return error(`cannot access fenv of builtin function '{source}'`, 2)
        end
    end
    builtin_funcs.low_level.deoptimize_env(result)
    return result
end
function _G.setfenv(target: number | (...any) -> any | nil, table: any)
    if typeof(table) ~= "table" then
        return error("function environment must be a table", 2)
    end

    local target_out, result, source = retrieve_target(target)
    if system_fenv[result] then
        if not source then
            return error("cannot set the global variables table for a protected context", 2)
        else
            return error(`cannot set fenv of builtin function '{source}'`, 2)
        end
    end

    builtin_funcs.low_level.deoptimize_env(table)
    if not target_out then
        builtin_funcs.low_level.set_globals(table)
    else
        builtin_funcs.low_level.raw_setfenv(target_out, table)
    end
end
