use crate::lua::stdlib::CrabSoupLib;
use mlua::{Lua, Result, Table};

mod htmllib;
mod stdlib;

const SHARED_TABLE_LOC: &str = "crabsoup-shared";

pub struct CrabsoupLuaContext {
    lua: Lua,
}
impl CrabsoupLuaContext {
    pub fn new() -> Result<Self> {
        let lua = Lua::new();

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
            //call!("rt/lua25_stdlib.luau");
            call!("rt/soupault_api.luau");
            call!("rt/soupault_html_api.luau");

            table
        };
        lua.set_named_registry_value(SHARED_TABLE_LOC, shared_table)?;

        // finish initialization
        lua.sandbox(true)?;
        Ok(CrabsoupLuaContext { lua })
    }

    pub fn repl(&self) -> Result<()> {
        let shared_table = self.lua.named_registry_value::<Table>(SHARED_TABLE_LOC)?;
        self.lua
            .load(include_str!("rt/ilua.lua"))
            .set_name("rt/ilua.lua")
            .call::<_, ()>(shared_table)?;
        Ok(())
    }
}
