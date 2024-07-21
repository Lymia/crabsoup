use mlua::{prelude::LuaString, Lua, Result, Table};
use std::{path::Path, time::UNIX_EPOCH};

pub fn create_sys_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    table.set(
        "read_file",
        lua.create_function(|_, path: LuaString| Ok(std::fs::read_to_string(path.to_str()?)?))?,
    )?;
    table.set(
        "write_file",
        lua.create_function(|_, (path, data): (LuaString, LuaString)| {
            std::fs::write(path.to_str()?, data.as_bytes())?;
            Ok(())
        })?,
    )?;
    table.set(
        "delete_file",
        lua.create_function(|_, path: LuaString| {
            std::fs::remove_file(path.to_str()?)?;
            Ok(())
        })?,
    )?;
    table.set(
        "delete_recursive",
        lua.create_function(|_, path: LuaString| {
            let path = path.to_str()?;
            if AsRef::<Path>::as_ref(path).is_dir() {
                std::fs::remove_dir_all(path)?;
            } else {
                std::fs::remove_file(path)?;
            }
            Ok(())
        })?,
    )?;
    table.set(
        "get_file_size",
        lua.create_function(|_, path: LuaString| Ok(std::fs::metadata(path.to_str()?)?.len()))?,
    )?;
    table.set(
        "file_exists",
        lua.create_function(|_, path: LuaString| Ok(std::fs::exists(path.to_str()?)?))?,
    )?;
    table.set(
        "is_file",
        lua.create_function(|_, path: LuaString| {
            Ok(AsRef::<Path>::as_ref(path.to_str()?).is_file())
        })?,
    )?;
    // TODO: get_file_modification_date -> get_file_modification_time (documentation error)
    table.set(
        "get_file_modification_time",
        lua.create_function(|_, path: LuaString| {
            Ok(std::fs::metadata(path.to_str()?)?
                .modified()?
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs())
        })?,
    )?;
    table.set(
        "is_dir",
        lua.create_function(|_, path: LuaString| {
            Ok(AsRef::<Path>::as_ref(path.to_str()?).is_dir())
        })?,
    )?;
    table.set(
        "mkdir",
        lua.create_function(|_, path: LuaString| Ok(std::fs::create_dir_all(path.to_str()?)?))?,
    )?;
    // TODO: Everything after Sys.list_dir

    Ok(table)
}
