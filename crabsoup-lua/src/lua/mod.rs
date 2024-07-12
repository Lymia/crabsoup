use anyhow::Result;
use mlua::Lua;

mod htmllib;

const SHARED_TABLE_LOC: &str = "crabsoup-shared";

pub struct CrabsoupLuaContext {
    lua: Lua,
}
impl CrabsoupLuaContext {
    pub fn new() -> Result<Self> {
        let lua = Lua::new();
        let shared_table = {
            let table = lua.create_table()?;

            macro_rules! call {
                ($source:expr) => {{
                    lua.load(include_str!($source))
                        .set_name($source)
                        .call::<_, ()>(&table)?;
                }};
            }

            call!("lua25_stdlib.luau");
            call!("soupault_api.luau");
            call!("soupault_html_api.luau");

            table
        };
        lua.set_named_registry_value(SHARED_TABLE_LOC, shared_table)?;

        Ok(CrabsoupLuaContext { lua })
    }
}
