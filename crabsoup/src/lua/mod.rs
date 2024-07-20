use mlua::{prelude::LuaFunction, ChunkMode, Lua, LuaOptions, Result, StdLib, Table, Thread};

mod baselib;
mod digestlib;
mod htmllib;
mod syslib;
mod utils;

const SHARED_TABLE_LOC: &str = "crabsoup-shared";

macro_rules! include_call {
    ($lua:expr, $source:expr, $shared:expr, $global:expr) => {{
        $lua.load(
            include_bytes!(concat!(env!("OUT_DIR"), "/luau_compiled/envs/", $source)).as_slice(),
        )
        .set_mode(ChunkMode::Binary)
        .set_name(concat!("@<rt>/envs/{}", $source))
        .call::<_, ()>((&$shared, &$global))?;
    }};
}

pub struct CrabsoupLuaContext {
    lua: Lua,
}
impl CrabsoupLuaContext {
    pub fn new() -> Result<Self> {
        let libs = StdLib::ALL ^ StdLib::PACKAGE;
        let lua = Lua::new_with(libs, LuaOptions::new())?;

        // setup operating environment
        {
            // Create the shared table
            let shared_table = lua.create_table()?;
            lua.set_named_registry_value(SHARED_TABLE_LOC, &shared_table)?;
            shared_table.set("baselib", baselib::create_base_table(&lua)?)?;
            shared_table.set("low_level", utils::load_unsafe_functions(&lua)?)?;

            // environments table store
            let envs_table = lua.create_table()?;
            shared_table.set("envs", &envs_table)?;

            // Global operating environment
            let global = lua.globals();
            envs_table.set("global", &global)?;
            global.set("Digest", digestlib::create_digest_table(&lua)?)?;
            global.set("HTML", htmllib::create_html_table(&lua)?)?;
            global.set("Sys", syslib::create_sys_table(&lua)?)?;
            include_call!(lua, "global/baselib.luau", shared_table, global);
            utils::sandbox_global_environment(&lua)?; // allows optimizations

            // Load shared environment (used to derive standalone + plugin envs)
            let shared_env = utils::clone_env_table(&lua, &lua.globals())?;
            shared_table.set("shared_env_base", &shared_env)?;
            include_call!(lua, "shared/0_lua5x_stdlib.luau", shared_table, shared_env);
            include_call!(lua, "shared/1_htmllib.luau", shared_table, shared_env);
            include_call!(lua, "shared/1_soupault_api.luau", shared_table, shared_env);
            include_call!(lua, "shared/2_ilua_pretty.lua", shared_table, shared_env);
            include_call!(lua, "shared/2_ilua_repl.lua", shared_table, shared_env);

            // Standalone environment
            let standalone_env = utils::clone_env_table(&lua, &shared_env)?;
            envs_table.set("standalone", &standalone_env)?;
            // TODO: Standalone-exclusive functions
            utils::create_sandbox_environment(&lua, standalone_env)?;

            // Plugin environment
            let plugin_env = utils::clone_env_table(&lua, &shared_env)?;
            envs_table.set("plugin", &plugin_env)?;
            include_call!(lua, "plugin/lua25_stdlib.luau", shared_table, plugin_env);
            include_call!(lua, "plugin/legacy_api.luau", shared_table, plugin_env);
            include_call!(lua, "plugin/legacy_htmllib.luau", shared_table, plugin_env);
            utils::create_sandbox_environment(&lua, plugin_env)?;

            // Finalize
            include_call!(lua, "finalize.luau", shared_table, global);
        }

        // finish initialization
        lua.sandbox(true)?;
        Ok(CrabsoupLuaContext { lua })
    }

    pub fn run_standalone(&self, code: &str, chunk_name: Option<&str>) -> Result<Thread> {
        let shared_table = self.lua.named_registry_value::<Table>(SHARED_TABLE_LOC)?;
        let thread = shared_table
            .get::<_, LuaFunction>("run_standalone")?
            .call::<_, Thread>((code, chunk_name))?;
        Ok(thread)
    }

    pub fn repl(&self) -> Result<()> {
        let shared_table = self.lua.named_registry_value::<Table>(SHARED_TABLE_LOC)?;
        shared_table
            .get::<_, LuaFunction>("run_repl_from_console")?
            .call::<_, ()>(())?;
        Ok(())
    }

    pub fn repl_in_plugin_env(&self) -> Result<()> {
        let shared_table = self.lua.named_registry_value::<Table>(SHARED_TABLE_LOC)?;
        shared_table
            .get::<_, LuaFunction>("run_repl_from_console_plugin")?
            .call::<_, ()>(())?;
        Ok(())
    }
}
