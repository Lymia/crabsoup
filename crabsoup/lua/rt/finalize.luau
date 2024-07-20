local builtin_funcs = ...

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
        builtin_funcs.register_builtin_name(value, path)
    end
end

local function for_env(v)
    register_builtins_for_env("", v, {})
    builtin_funcs.mark_system_fenv(v)
end

-- A few specific overrides in special cases
builtin_funcs.register_builtin_name(HTML.delete, "HTML.delete")

-- Register the various envs properly
for_env(builtin_funcs.envs.global)
for_env(builtin_funcs.envs.standalone)
for_env(builtin_funcs.envs.plugin)
