local shared, _G = ...

-- Helper functions
local function starts_with(str: string, start: string): boolean
    return start == "" or string.sub(str, 1, #start) == start
end

local function deep_copy(env)
    if type(env) == "table" then
        local new = {}
        for k, v in env do
            if k ~= "_G" then
                new[k] = deep_copy(v)
            end
        end
        return new
    else
        return env
    end
end

local function call_env_chunks(env, ...)
    shared.baselib.debug(`Loading Lua environment: {env}`)

    local dir = `envs/{env}/`
    local files = {}
    for name in shared.sources do
        if starts_with(name, dir) then
            table.insert(files, name)
        end
    end

    table.sort(files)
    for _, name in files do
        local chunk = shared.sources[name]
        shared.baselib.debug(`- Loading runtime sources: @<rt>/{name}`)
        local func = shared.baselib.loadstring_rt(chunk, `@<rt>/{name}`)
        func(...)
    end
end

local function freeze_env(env)
    local function iter(env, seen)
        if seen[env] then
            return
        end
        seen[env] = true
        if typeof(env) == "table" then
            for k, v in env do
                iter(v, seen)
            end
            table.freeze(env)
        end
    end
    env._G = env
    iter(env, {})
    shared.baselib.set_safeenv_flag(env)
end

local function register_builtins_for_env(path: string, value: any, seen)
    if seen[value] then
        return
    end
    seen[value] = true

    if typeof(value) == "table" then
        for k, v in value do
            if typeof(k) == "string" then
                local new_path = if #path == 0 then k else `{path}.{k}`
                register_builtins_for_env(new_path, v, seen)
            end
        end
    elseif typeof(value) == "function" then
        shared.register_builtin_name(value, path)
    end
end

local function for_env(v)
    register_builtins_for_env("", v, {})
    shared.mark_system_fenv(v)
end

-- Setup global environment
_G.Digest = shared.Digest
_G.HTML = shared.HTML
_G.Sys = shared.Sys
call_env_chunks("global", shared, _G)
shared.baselib.do_sandbox()

-- Setup shared environment
local shared_env = deep_copy(_G)
call_env_chunks("shared", shared, shared_env)
freeze_env(shared_env)

-- Manually set a few specific functions names that are aliased even in the standalone environment
shared.register_builtin_name(shared_env.HTML.append, "HTML.append")
shared.register_builtin_name(shared_env.HTML.delete, "HTML.delete")
shared.register_builtin_name(shared_env.HTML.prepend, "HTML.prepend")

-- Setup each specific environment
shared.envs = { global = _G, shared = shared_env }
for_env(_G)
for_env(shared_env)
for _, env in { "standalone", "plugin" } do
    local env_table = deep_copy(shared_env)
    call_env_chunks(env, shared, env_table)
    freeze_env(env_table)
    for_env(env_table)
    shared.envs[env] = env_table
end

-- Helper functions used by Rust code
function shared.run_standalone(string, chunk_name)
    local env = shared.envs.standalone
    local function loader(...)
        local chunk = shared.baselib.loadstring(string, chunk_name)
        return chunk(...)
    end
    return shared.baselib.load_in_new_thread(loader, env)
end

function shared.run_repl_from_console()
    shared.run_repl_in_env(shared.envs.standalone)
end

function shared.run_repl_from_console_plugin()
    shared.run_repl_in_env(shared.envs.plugin)
end
