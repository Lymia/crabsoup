local shared = ...

local module = {}
local sources = shared.sources

-- build table for standalone ctx
do
    local function common_deps(analyzer)
        analyzer:add_definitions("defs_shared", sources["defs/defs_shared.d_lua"])
        analyzer:add_definitions("defs_standalone", sources["defs/defs_standalone.d_lua"])
    end

    module.standalone = {}
    module.standalone.require_ctx = shared.analyze.create(function(analyzer)
        common_deps(analyzer)
    end)
    module.standalone.plugin_ctx = shared.analyze.create(function(analyzer)
        common_deps(analyzer)
        analyzer:add_definitions("defs_plugin_globals", sources["defs/defs_plugin_globals.d_lua"])
    end)
end

-- build table for plugin ctx
do
    local function common_deps(analyzer)
        analyzer:add_definitions("defs_shared", sources["defs/defs_shared.d_lua"])
        analyzer:add_definitions("defs_plugin", sources["defs/defs_plugin.d_lua"])
        analyzer:add_definitions("defs_legacy_alias", sources["defs/defs_legacy_alias.d_lua"])
    end
    local function deprecations(analyzer)
        -- Value table
        analyzer:set_deprecation("Value.is_nil", "x == nil")
        analyzer:set_deprecation("Value.is_float", 'type(x) == "number"')
        analyzer:set_deprecation("Value.is_string", 'type(x) == "string"')
        analyzer:set_deprecation("Value.is_table", 'type(x) == "table"')
        analyzer:set_deprecation("Value.is_html", 'typeof(x) == "NodeRef"')
    end

    module.plugin = {}
    module.plugin.require_ctx = shared.analyze.create(function(analyzer)
        common_deps(analyzer)
        deprecations(analyzer)
    end)
    module.plugin.plugin_ctx = shared.analyze.create(function(analyzer)
        common_deps(analyzer)
        analyzer:add_definitions("defs_plugin_globals", sources["defs/defs_plugin_globals.d_lua"])
        deprecations(analyzer)
    end)
end

return module
