use crate::lua::stdlib::CrabSoupLib;
use mlua::{prelude::LuaFunction, Lua, LuaOptions, Result, StdLib, Table};

mod htmllib;
mod stdlib;

const SHARED_TABLE_LOC: &str = "crabsoup-shared";

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
            table.set("crabsoup", CrabSoupLib)?;

            macro_rules! call {
                ($source:expr) => {{
                    lua.load(include_str!($source))
                        .set_name($source)
                        .call::<_, ()>(&table)?;
                }};
            }

            call!("rt/lua5x_stdlib.luau");
            call!("rt/lua25_stdlib.luau");
            call!("rt/ilua_pretty.lua");
            call!("rt/ilua_repl.lua");
            call!("rt/soupault_api.luau");
            call!("rt/soupault_html_api.luau");
            call!("rt/crabsoup_ext_api.luau");

            table
        };
        lua.set_named_registry_value(SHARED_TABLE_LOC, shared_table)?;

        // finish initialization
        lua.sandbox(true)?;
        Ok(CrabsoupLuaContext { lua })
    }

    pub fn repl(&self) -> Result<()> {
        let shared_table = self.lua.named_registry_value::<Table>(SHARED_TABLE_LOC)?;
        shared_table
            .get::<_, LuaFunction>("run_repl_from_console")?
            .call::<_, ()>(())?;
        Ok(())
    }
}
