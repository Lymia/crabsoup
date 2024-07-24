use mlua::{prelude::LuaFunction, ChunkMode, Lua, LuaOptions, Result, StdLib, Table, Thread};

mod baselib;
mod codeclib;
mod datelib;
mod digestlib;
mod htmllib;
mod processlib;
mod stringlib;
mod syslib;

const SHARED_TABLE_LOC: &str = "crabsoup-shared";

include!(concat!(env!("OUT_DIR"), "/luau_modules.rs"));

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
            shared_table.set("codecs", codeclib::create_codec_table(&lua)?)?;
            shared_table.set("Date", datelib::create_date_table(&lua)?)?;
            shared_table.set("Digest", digestlib::create_digest_table(&lua)?)?;
            shared_table.set("HTML", htmllib::create_html_table(&lua)?)?;
            shared_table.set("Process", processlib::create_process_table(&lua)?)?;
            shared_table.set("String", stringlib::create_string_table(&lua)?)?;
            shared_table.set("Sys", syslib::create_sys_table(&lua)?)?;

            // Create the lua data table
            let sources = load_lua_sources();
            let sources_table = lua.create_table()?;
            for (&name, &source) in &sources {
                sources_table.set(name, lua.create_string(source)?)?;
            }
            shared_table.set("sources", &sources_table)?;

            // Load initialization code.
            lua.load(*sources.get("init.luau").unwrap())
                .set_name("@<rt>/init.luau")
                .set_mode(ChunkMode::Binary)
                .call::<_, ()>((&shared_table, &lua.globals()))?;
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
