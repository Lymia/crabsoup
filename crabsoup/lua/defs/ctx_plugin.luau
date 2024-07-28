local sources, analyzer = ...

analyzer:add_definitions("defs_shared", sources["defs/defs_shared.d_lua"])
analyzer:add_definitions("defs_plugin", sources["defs/defs_plugin.d_lua"])
