--!strict

local shared, _G = ...
local baselib = shared.baselib

-- imported global functions
local debug_info = debug.info
local error = error
local math_round = math.round
local string_gsub = string.gsub
local string_sub = string.sub

-- Globals
_G._CRABSOUP_VERSION = baselib._VERSION

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

-- Extensions to the standard math API
_G.math.isnan = baselib.is_nan
_G.math.isinf = baselib.is_inf
_G.math.isfinite = baselib.is_finite

-- Sandboxed versions of setfenv and getfenv
shared.orig_setfenv = _G.setfenv
shared.orig_getfenv = _G.getfenv

_G.setfenv = nil
_G.getfenv = nil

local system_fenv = {}
function shared.mark_system_fenv(env)
    system_fenv[env] = true
end

local function get_function_for_level(level: number): (...any) -> any
    if not baselib.is_finite(level) or math_round(level) ~= level then
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
        result = baselib.get_globals()
    else
        if type(target) == "number" then
            target_out = get_function_for_level(target)
            result = baselib.raw_getfenv(target_out)
            source = shared.fn2str(target_out)
        elseif type(target) == "function" then
            target_out = target
            result = baselib.raw_getfenv(target)
            source = shared.fn2str(target)
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
    baselib.deoptimize_env(result)
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

    baselib.deoptimize_env(table)
    if not target_out then
        baselib.set_globals(table)
    else
        baselib.raw_setfenv(target_out, table)
    end
end

-- Reimplement base library functions
local getfenv = _G.getfenv
local function loadstring(chunk: string, chunkname: string?, mode: string?, env: any?): (((...any) -> any)?, string?)
    if type(chunk) ~= "string" then
        return error("chunk must be a string")
    end
    if chunkname and type(chunkname) ~= "string" then
        return error("chunk name must be a string or nil")
    end
    if env and type(env) ~= "table" then
        return error("function environment must be a table or nil")
    end

    if mode then
        baselib.warn("`mode` is ignored on `loadstring` and `load`")
    end

    if not env then
        env = getfenv(2)
    end
    baselib.deoptimize_env(env)
    return baselib.loadstring(chunk, chunkname, env)
end

function _G.load(
    chunk: () -> string? | string,
    chunkname: string?,
    mode: string?,
    env: any?
): (((...any) -> any)?, string?)
    local code
    if type(chunk) == "string" then
        code = chunk
    elseif type(chunk) == "function" then
        code = ""
        while true do
            local section = chunk()
            if section and #section > 0 then
                code += section
            else
                break
            end
        end
    else
        return error("Chunk function given to `load` must be a function or string.", 2)
    end
    if not env then
        env = getfenv(2)
    end
    return loadstring(code, chunkname, mode, env)
end

_G.loadstring = loadstring

function _G.loadfile(filename: string, mode: string?, env: any?): (((...any) -> any)?, string?)
    return load(Sys.read_file(filename), `@{filename}`, mode, env)
end

function _G.dofile(filename: string, mode: string?, env: any?): any
    local chunk, err = loadfile(filename, mode, env)
    if chunk then
        return chunk()
    else
        return error(err, 2)
    end
end
