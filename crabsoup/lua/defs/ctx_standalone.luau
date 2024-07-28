local sources, analyzer = ...

analyzer:add_definitions("defs_shared", sources["defs/defs_shared.d_lua"])
analyzer:add_definitions("defs_standalone", sources["defs/defs_standalone.d_lua"])
