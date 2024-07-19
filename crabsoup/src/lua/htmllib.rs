use mlua::{prelude::LuaString, Lua, Result, Table};

pub fn create_html_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    // Parsing and rendering
    table.set(
        "parse",
        lua.create_function(|_, text: LuaString| {
            let str = text.to_str()?;
            todo!();
            Ok(())
        })?,
    )?;

    table.set_readonly(true);
    Ok(table)
}
