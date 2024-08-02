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
        -- CSV library
        analyzer:set_deprecation("CSV.unsafe_from_string", "pcall(CSV.from_string, x)")

        -- JSON library
        analyzer:set_deprecation("JSON.unsafe_from_string", "pcall(JSON.from_string, x)")

        -- String library
        analyzer:set_deprecation("String.is_valid_utf8", "utf8.len(x) ~= nil")
        analyzer:set_deprecation("String.length", "utf8.len")
        analyzer:set_deprecation("String.length_ascii", "#str")
        analyzer:set_deprecation("String.trim", "string.trim")
        analyzer:set_deprecation("String.to_number", "tonumber")
        analyzer:set_deprecation("String.join", "table.concat")
        analyzer:set_deprecation("String.starts_with", "string.starts_with")
        analyzer:set_deprecation("String.ends_with", "string.ends_with")

        -- Sys library
        analyzer:set_deprecation("Sys.get_file_modification_date", "Sys.get_file_modification_time")
        analyzer:set_deprecation("Sys.run_program", "Process.run")
        analyzer:set_deprecation("Sys.run_program_get_exit_code", "Process.try_run")
        analyzer:set_deprecation("Sys.get_program_output", "Process.run_output")
        analyzer:set_deprecation("Sys.random", "math.random")

        -- Table library
        analyzer:set_deprecation("Table.has_key", "table[x]")

        -- TOML library
        analyzer:set_deprecation("TOML.unsafe_from_string", "pcall(TOML.from_string, x)")

        -- Value library
        analyzer:set_deprecation("Value.is_nil", "x == nil")
        analyzer:set_deprecation("Value.is_float", 'type(x) == "number"')
        analyzer:set_deprecation("Value.is_string", 'type(x) == "string"')
        analyzer:set_deprecation("Value.is_table", 'type(x) == "table"')
        analyzer:set_deprecation("Value.is_html", 'typeof(x) == "NodeRef"')

        -- YAML library
        analyzer:set_deprecation("YAML.unsafe_from_string", "pcall(YAML.from_string, x)")
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
