--!strict

local shared, _G = ...

-- Function definitions for `Plugin` module
local Plugin = _G.Plugin or {}
_G.Plugin = Plugin

local env_standalone = shared.baselib.create_opaque_environment()
local env_plugin = shared.baselib.create_opaque_environment()

Plugin.env_standalone = env_standalone
Plugin.env_plugin = env_plugin

function Plugin.load_plugin(
    name: string,
    source: string,
    env: Environment,
    allowed_globals: { string }?
): (globals: { [string]: any }) -> thread
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

    local analyzer, env_table
    if env == env_standalone then
        analyzer = shared.analyzer.standalone
        env_table = shared.envs.standalone
    elseif env == env_plugin then
        analyzer = shared.analyzer.plugin
        env_table = shared.envs.plugin
    else
        error("unknown environment variable", 2)
    end

    shared.analyze.check(analyzer, name, source)
    local chunk = shared.baselib.compile_for_environment(source, allowed_globals)
    local chunkname = `@{name}`

    local load_chunk = function()
        return shared.baselib.load_precompiled_chunk(chunk, chunkname)()
    end

    return function(global_values: { [string]: any }?)
        local new_table = {}
        if global_values then
            for k, v in global_values do
                if not parsed_globals[k] then
                    error(`Global not allowed: {tostring(k)}`, 2)
                end
                new_table[k] = v
            end
        end

        return shared.baselib.load_in_new_thread(load_chunk, setmetatable(new_table, { __index = env_table }))
    end
end