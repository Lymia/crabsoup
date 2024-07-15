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

for _, v in builtin_funcs.envs do
    register_builtins_for_env("", v, {})
end
