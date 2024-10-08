--!strict

local module = {}

type LoadedPlugin = (globals: { [string]: any }, name_tag: string?) -> thread
type PluginManager = typeof(setmetatable({} :: PluginManager_fields, {} :: PluginManager_mt))
type PluginManager_fields = {
    require_ctx: RequireEnv,
    require: typeof(require),
    plugins: { [string]: LoadedPlugin },
}
type PluginManager_mt = {
    __index: PluginManager_methods,
}
type PluginManager_methods = {
    register_plugin: (self: PluginManager, path: string, r_name: string?, override: boolean?) -> (),
    register_inline_plugin: (self: PluginManager, name: string, source: string, override: boolean?) -> (),
    register_plugin_from_toml: (self: PluginManager, config: any) -> (),
    register_plugins_from_dir: (self: PluginManager, dir: string) -> (),
    resolve: (self: PluginManager, name: string) -> LoadedPlugin,
}

local PluginManager: PluginManager_methods = {} :: PluginManager_methods
local PluginManager_mt: PluginManager_mt = { __index = PluginManager }

local plugin_globals = {
    "page",
    "page_file",
    "target_dir",
    "target_file",
    "nav_path",
    "page_url",
    "config",
    "soupault_config",
    "site_index",
    "index_entry",
    "site_dir",
    "build_dir",
    "persistent_data",
    "global_data",
    "soupault_pass",

    -- Hook-specific globals
    "force",
    "page_source",
    "hook_config",

    -- crabsoup extensions
    "relative_page_file",
    "global_config",
    "parsed_config",
    "widget_name",
}

local builtin_modules = { "widget.basic", "widget.toc" }

function module.create_plugin_manager(lib_path)
    local require_ctx = Plugin.create_require_env(lib_path, Plugin.env_plugin)
    return setmetatable({
        require_ctx = require_ctx,
        require = Plugin.create_require_func(require_ctx),
        plugins = {},
    }, PluginManager_mt)
end

function PluginManager:register_plugin(path, r_name, override)
    local name = if not r_name then Sys.strip_all_extensions(Sys.basename(path)) else r_name
    if self.plugins[name] and not override then
        error(`Duplicate plugin registered: {name}`)
    end
    self.plugins[name] = Plugin.load_plugin(self.require_ctx, path, Sys.read_file(path), plugin_globals)
end

function PluginManager:register_inline_plugin(name, source, override)
    if self.plugins[name] and not override then
        error(`Duplicate plugin registered: {name}`)
    end
    self.plugins[name] = Plugin.load_plugin(self.require_ctx, name, source, plugin_globals)
end

local function load_plugin(self, table_name, prefix, table)
    for k, v in table do
        if v.file and v.lua_source then
            error(`'[{table_name}.{k}]' declares both a 'file' and 'lua_source' field. Please only use one.`)
        elseif v.file then
            self:register_plugin(v.file, `{prefix}{k}`)
        elseif v.lua_source then
            self:register_inline_plugin(`{prefix}{k}`, v.lua_source)
        else
            error(`'[{table_name}.{k}]' does not declare a 'file' our 'lua_source' field.`)
        end
    end
end

function PluginManager:register_plugin_from_toml(config)
    for _, v in builtin_modules do
        local module = require(v)
        for k, v in module do
            self.plugins[k] = function(globals)
                return coroutine.create(function()
                    return module[k](globals)
                end)
            end
        end
    end

    if config.parsed.settings.plugin_discovery then
        for _, v in config.parsed.settings.plugin_dirs do
            self:register_plugins_from_dir(v)
        end
    end

    load_plugin(self, "plugin", "", config.parsed.plugins)
    load_plugin(self, "hooks", "$hook:", config.parsed.plugins)
end

function PluginManager:register_plugins_from_dir(dir)
    for _, file in Sys.glob(`{dir}/**/*`) do
        if string.endswith(file, ".lua") or string.endswith(file, ".luau") then
            self:register_plugin(file)
        end
    end
end

function PluginManager:resolve(name)
    if self.plugins[name] then
        return self.plugins[name]
    else
        error(`No such plugin '{name}'!`)
    end
end

return module
