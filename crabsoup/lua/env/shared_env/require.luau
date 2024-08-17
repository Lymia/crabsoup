--!strict

local shared, _G = ...

local Plugin = _G.Plugin or {}
_G.Plugin = Plugin

-- Environment implementation
local env_standalone = shared.baselib.create_opaque_environment()
local env_plugin = shared.baselib.create_opaque_environment()

Plugin.env_standalone = env_standalone
Plugin.env_plugin = env_plugin

local function retrieve_env(env: Environment)
    if env == env_standalone then
        return shared.analyzer.standalone, shared.envs.standalone
    elseif env == env_plugin then
        return shared.analyzer.plugin, shared.envs.plugin
    else
        error("unknown environment variable", 2)
    end
end

-- require-related definitions
local opaque_key = shared.baselib.opaque_key
local raw_getmetatable = shared.baselib.raw_getmetatable
local require_ctx_metatable = {
    __metatable = false,
    -- key fields
    opaque_key = opaque_key,
    opaque_ty = "RequireEnv",
}

type RequireEnv = typeof(setmetatable(newproxy(), require_ctx_metatable))

local function retrieve_metadata(ctx: RequireEnv)
    if typeof(ctx) == "userdata" then
        local mt = raw_getmetatable(ctx)
        if mt.opaque_key == opaque_key and mt.opaque_ty == "RequireEnv" then
            return mt
        end
    end
    return error("Function requires a RequireEnv object", 3)
end

-- base code for loading plugins
local create_require_func
local function compile_chunk(
    require_env: RequireEnv,
    chunkname: string,
    chunk: string,
    parsed_globals: { [string]: boolean },
    is_module: boolean
): (globals: { [string]: any }?) -> thread
    parsed_globals["require"] = true
    parsed_globals["require_env"] = true

    local allowed_globals = {}
    for k, v in parsed_globals do
        if v then
            table.insert(allowed_globals, k)
        end
    end

    local mt = retrieve_metadata(require_env)
    local check_result = shared.analyze.check(if is_module then mt.analyzer_module else mt.analyzer, chunkname, chunk)
    if not check_result and mt.strict then
        return error(`Type error in '{chunkname}'!`)
    end

    shared.baselib.debug(`Compiling chunk '{chunkname}'...`)
    local compiled_chunk = shared.baselib.compile_for_environment(chunk, allowed_globals)

    local function result_helper(status, ...)
        if status then
            return ...
        else
            local msg = ...
            error(msg)
        end
    end

    local require_func = create_require_func(require_env)

    return function(global_values: { [string]: any }?, name_tag: string?)
        local full_chunkname = chunkname
        if name_tag then
            local temp_tag = Sys.strip_extension(Sys.basename(name_tag))
            if temp_tag == "index" and temp_tag ~= Sys.strip_extension(temp_tag) then
                temp_tag = Sys.strip_extension(Sys.basename(Sys.dirname(name_tag)))
            end
            full_chunkname ..= `#{temp_tag}`
        end

        shared.baselib.trace(`Loading chunk '{full_chunkname}'...`)

        local load_chunk = function()
            local func = shared.baselib.load_precompiled_chunk(compiled_chunk, full_chunkname)
            return result_helper(xpcall(func, debug.traceback, full_chunkname))
        end

        local new_table = {}
        if global_values then
            for k, v in global_values do
                if k == "require" or k == "require_env" then
                    return error("require and require_env are reserved.", 2)
                end
                if not parsed_globals[k] then
                    return error(`Global not allowed: {tostring(k)}`, 2)
                end
                new_table[k] = v
            end
        end

        new_table["require"] = require_func
        new_table["require_env"] = require_env

        return shared.baselib.load_in_new_thread(load_chunk, setmetatable(new_table, { __index = mt.env_table }))
    end
end
local function compile_preloaded_chunk(
    require_env: RequireEnv,
    chunkname: string,
    chunk: string
): (globals: { [string]: any }?) -> thread
    local mt = retrieve_metadata(require_env)
    local require_func = create_require_func(require_env)

    local load_chunk = function()
        return shared.baselib.loadstring_rt(chunk, chunkname)(chunkname)
    end
    return function(global_values: { [string]: any }?)
        shared.baselib.trace(`Loading builtin chunk '{chunkname}'...`)

        if global_values then
            for _ in global_values do
                return error("Globals are not allowed to be defined with preloaded chunks.", 2)
            end
        end
        local new_table = {
            require = require_func,
            require_env = require_env,
        }
        return shared.baselib.load_in_new_thread(load_chunk, setmetatable(new_table, { __index = mt.env_table }))
    end
end

-- load_plugin implementation
function Plugin.load_plugin(
    ctx: RequireEnv,
    name: string,
    source: string,
    allowed_globals: { string }?
): (globals: { [string]: any }?, name_tag: string?) -> thread
    local parsed_globals = {}
    if allowed_globals then
        for k, v in allowed_globals do
            if type(k) == "number" and type(v) == "string" then
                parsed_globals[v] = true
            else
                error("allowed_globals is not { [number]: string }", 2)
            end
        end
    end

    return compile_chunk(ctx, `@{name}`, source, parsed_globals, false)
end

-- Require implementation
local function split_path(path: string): { string }
    if path == "" then
        return {}
    end

    local result = {}
    for _, str in string.split(path, ";") do
        str = string.trim(str)
        if str == "" then
            return error(`Empty path in split path: {path}`, 3)
        end
        if not string.find(str, "?") then
            return error(`No wildcard found in path: {str}`, 3)
        end
        table.insert(result, str)
    end
    return result
end
function Plugin.create_require_env(sources_path: string, env: Environment): RequireEnv
    if type(sources_path) ~= "string" then
        return error("sources path must be a string", 2)
    end

    local mt = table.clone(require_ctx_metatable)
    local analyzer, env_table = retrieve_env(env)
    mt.analyzer = analyzer.plugin_ctx
    mt.analyzer_module = analyzer.require_ctx
    mt.env_table = env_table
    mt.sources_path = split_path(sources_path)
    mt.compiled_chunks_path = {}
    mt.preload = {}
    mt.strict = false
    return shared.baselib.raw_setmetatable(newproxy(), mt)
end

function shared.attach_compiled_chunks(ctx: RequireEnv, path: string)
    local mt = retrieve_metadata(ctx)
    mt.compiled_chunks_path = split_path(path)
end

function Plugin.require_add_preload(ctx: RequireEnv, name: string, value: any)
    local mt = retrieve_metadata(ctx)
    mt.preload[name] = value
end

function Plugin.require_set_strict(ctx: RequireEnv)
    local mt = retrieve_metadata(ctx)
    mt.strict = true
end

local function process_path(path: string): string
    if string.find(path, "/") or string.find(path, "\\") then
        return error(`Module path should not contain slashes: {path}`, 3)
    end
    if string.find(path, "%.%.") then
        return error(`Module path should not contain double dots: {path}`, 3)
    end

    local rep_path = string.gsub(path, "%.", "/")
    if string.startswith(rep_path, "/") or string.endswith(rep_path, "/") then
        return error(`Module path should not start or end with a dot: {path}`, 3)
    end
    return rep_path
end
local function try_resolve_compiled_path(paths: { string }, path_fragment: string): (string?, string?, string?)
    local fragment = ""
    for _, path in paths do
        local full_path = string.gsub(path, "?", path_fragment)
        if shared.sources[full_path] then
            return shared.sources[full_path], full_path
        end
        fragment ..= `\tno runtime file '{full_path}'\n`
    end
    return nil, nil, fragment
end
local function try_resolve_path(paths: { string }, path_fragment: string): (string?, string?, string?)
    local fragment = ""
    for _, path in paths do
        local full_path = string.gsub(path, "?", path_fragment)
        if Sys.file_exists(full_path) then
            if Sys.is_file(full_path) then
                return Sys.read_file(full_path), full_path
            end
            fragment ..= `\tnot a file '{full_path}'\n`
        else
            fragment ..= `\tno file '{full_path}'\n`
        end
    end
    return nil, nil, fragment
end
local function try_resolve(
    require_env: RequireEnv,
    mt,
    path_fragment: string
): (((globals: { [string]: any }?) -> thread)?, string?)
    local fragment = ""

    local chunk, chunkname, new_fragment = try_resolve_path(mt.sources_path, path_fragment)
    if chunk and chunkname then
        return compile_chunk(require_env, `@{chunkname}`, chunk, {}, true)
    end
    assert(new_fragment)
    fragment ..= new_fragment

    chunk, chunkname, new_fragment = try_resolve_compiled_path(mt.compiled_chunks_path, path_fragment)
    if chunk and chunkname then
        local full_name
        if string.startswith(chunkname, "app/") then
            full_name = `@<app>/{string.sub(chunkname, 5)}`
        elseif string.startswith(chunkname, "env/") then
            full_name = `@<env>/{string.sub(chunkname, 6)}`
        else
            full_name = `@<rt>/{chunkname}`
        end
        return compile_preloaded_chunk(require_env, full_name, chunk)
    end
    assert(new_fragment)
    fragment ..= new_fragment

    return nil, fragment
end
function Plugin.create_require_func(ctx: RequireEnv): (string) -> any
    local mt = retrieve_metadata(ctx)
    if not mt.require_func then
        local loaded = {}
        mt.require_func = function(name)
            if loaded[name] then
                return loaded[name]
            end

            local path_fragment = process_path(name)
            local fragment = ""

            local preload = mt.preload[name]
            if preload then
                loaded[name] = preload
                return preload
            else
                fragment ..= `\tno preload '{name}'\n`
            end

            local chunk, new_fragment = try_resolve(ctx, mt, path_fragment)
            if chunk then
                local thread = chunk()
                local result, value = coroutine.resume(thread)
                if not result then
                    return error(`require failed: {value}`, 2)
                end
                if coroutine.status(thread) ~= "dead" then
                    return error("require module yielded instead of returning", 2)
                end

                if not value then
                    value = true
                    shared.baselib.warn(`Module '{name}' returned no value. This is likely not what you want.`)
                end
                loaded[name] = value

                return value
            end
            assert(new_fragment)
            fragment ..= new_fragment

            return error(`module '{name}' not found:\n{fragment}`, 2)
        end
    end
    return mt.require_func
end
create_require_func = Plugin.create_require_func
