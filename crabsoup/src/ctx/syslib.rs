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
    table.set(
        "list_dir",
        lua.create_function(|lua, path: LuaString| {
            let table = lua.create_table()?;
            for dir in std::fs::read_dir(path.to_str()?)? {
                let dir = dir?;
                table.push(dir.file_name().to_string_lossy())?;
            }
            Ok(table)
        })?,
    )?;
    table.set(
        "get_extension",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();
            if str.contains('.') {
                Ok(Some(lua.create_string(str.split('.').last().unwrap())?))
            } else {
                Ok(None)
            }
        })?,
    )?;
    table.set(
        "get_extensions",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();

            let table = lua.create_table()?;
            for str in str.split('.').skip(1) {
                table.push(str)?;
            }
            Ok(table)
        })?,
    )?;
    table.set(
        "has_extension",
        lua.create_function(|_, (path, extension): (LuaString, LuaString)| {
            let path = path.to_str()?;
            let extension = extension.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();
            Ok(str.split('.').skip(1).any(|x| x == extension))
        })?,
    )?;
    table.set(
        "strip_extensions",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();
            lua.create_string(str.split('.').next().unwrap())
        })?,
    )?;
    table.set(
        "basename",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            lua.create_string(path.file_name().unwrap().to_string_lossy().as_ref())
        })?,
    )?;
    table.set(
        "basename_unix",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            lua.create_string(path.trim_end_matches('/').split('/').last().unwrap_or(""))
        })?,
    )?;
    table.set(
        "dirname",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            match path.parent() {
                None => lua.create_string(""),
                Some(parent) => lua.create_string(parent.to_string_lossy().as_ref()),
            }
        })?,
    )?;
    table.set(
        "dirname_unix",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            match path.rsplit_once('/') {
                None => lua.create_string(""),
                Some(("", _)) => lua.create_string("/"),
                Some((str, _)) => lua.create_string(str),
            }
        })?,
    )?;
    // TODO: Everything after Sys.join_path

    Ok(table)
}
