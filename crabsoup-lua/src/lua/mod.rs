use crate::lua::baselib::CrabSoupLib;
use mlua::{prelude::LuaFunction, Lua, LuaOptions, Result, StdLib, Table, Thread};

mod baselib;
mod htmllib;
mod utils;

const SHARED_TABLE_LOC: &str = "crabsoup-shared";

macro_rules! include_call {
    ($lua:expr, $source:expr, $shared:expr, $global:expr) => {{
        $lua.load(include_str!($source))
            .set_name($source)
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
        let shared_table = {
            let table = lua.create_table()?;

            // internal libraries
            table.set("crabsoup", CrabSoupLib)?;
            table.set("low_level", utils::load_unsafe_functions(&lua)?)?;

            // environments table store
            let envs_table = lua.create_table()?;
            table.set("envs", &envs_table)?;

            // Global operating environment
            let global = lua.globals();
            include_call!(lua, "rt/global_env/baselib.luau", table, global);
            include_call!(lua, "rt/global_env/ilua_pretty.lua", table, global);
            include_call!(lua, "rt/global_env/ilua_repl.lua", table, global);
            utils::sandbox_global_environment(&lua)?;

            // Standalone environment
            let standalone_env = utils::clone_env_table(&lua, lua.globals())?;
            envs_table.set("standalone", &standalone_env)?;
            include_call!(lua, "rt/shared_env/lua5x_stdlib.luau", table, standalone_env);
            include_call!(lua, "rt/shared_env/soupault_api.luau", table, standalone_env);
            include_call!(lua, "rt/shared_env/html_api.luau", table, standalone_env);
            include_call!(lua, "rt/shared_env/crabsoup_ext_api.luau", table, standalone_env);
            utils::create_sandbox_environment(&lua, standalone_env)?;

            // Plugin environment
            let plugin_env = utils::clone_env_table(&lua, lua.globals())?;
            envs_table.set("plugin", &plugin_env)?;
            include_call!(lua, "rt/shared_env/lua5x_stdlib.luau", table, plugin_env);
            include_call!(lua, "rt/shared_env/soupault_api.luau", table, plugin_env);
            include_call!(lua, "rt/shared_env/html_api.luau", table, plugin_env);
            include_call!(lua, "rt/shared_env/crabsoup_ext_api.luau", table, plugin_env);
            include_call!(lua, "rt/plugin_env/lua25_stdlib.luau", table, plugin_env);
            include_call!(lua, "rt/plugin_env/legacy_api.luau", table, plugin_env);
            utils::create_sandbox_environment(&lua, plugin_env)?;

            // Returns the shared table
            table
        };
        lua.set_named_registry_value(SHARED_TABLE_LOC, shared_table)?;

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
}
