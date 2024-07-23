use base64::Engine;
use mlua::{prelude::LuaString, Error, Lua, Result, Table};

pub fn create_string_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    table.set(
        "base64_encode",
        lua.create_function(|lua, str: LuaString| {
            lua.create_string(base64::engine::general_purpose::STANDARD.encode(str.as_bytes()))
        })?,
    )?;
    table.set(
        "base64_decode",
        lua.create_function(|lua, str: LuaString| {
            lua.create_string(
                base64::engine::general_purpose::STANDARD
                    .decode(str.as_bytes())
                    .map_err(Error::runtime)?,
            )
        })?,
    )?;
    table.set(
        "url_encode",
        lua.create_function(|lua, str: LuaString| {
            lua.create_string(&*urlencoding::encode(str.to_str()?))
        })?,
    )?;
    table.set(
        "url_decode",
        lua.create_function(|lua, str: LuaString| {
            lua.create_string(&*urlencoding::decode(str.to_str()?).map_err(Error::runtime)?)
        })?,
    )?;

    Ok(table)
}
