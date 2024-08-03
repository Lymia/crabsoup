use mlua::{prelude::LuaString, Error, Lua, Result, Table, Value};
use std::{
    path::{Path, PathBuf},
    time::{Duration, UNIX_EPOCH},
};

const MICROS: f64 = 1000000.0;

pub fn create_sys_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    table.raw_set(
        "read_file",
        lua.create_function(|lua, path: LuaString| {
            Ok(lua.create_string(std::fs::read(path.to_str()?)?)?)
        })?,
    )?;
    table.raw_set(
        "write_file",
        lua.create_function(|_, (path, data): (LuaString, LuaString)| {
            std::fs::write(path.to_str()?, data.as_bytes())?;
            Ok(())
        })?,
    )?;
    table.raw_set(
        "delete_file",
        lua.create_function(|_, path: LuaString| {
            std::fs::remove_file(path.to_str()?)?;
            Ok(())
        })?,
    )?;
    table.raw_set(
        "copy_file",
        lua.create_function(|_, (src, dst): (LuaString, LuaString)| {
            std::fs::copy(src.to_str()?, dst.to_str()?)?;
            Ok(())
        })?,
    )?;
    table.raw_set(
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
    table.raw_set(
        "get_file_size",
        lua.create_function(|_, path: LuaString| Ok(std::fs::metadata(path.to_str()?)?.len()))?,
    )?;
    table.raw_set(
        "file_exists",
        lua.create_function(|_, path: LuaString| Ok(std::fs::exists(path.to_str()?)?))?,
    )?;
    table.raw_set(
        "is_file",
        lua.create_function(|_, path: LuaString| {
            Ok(AsRef::<Path>::as_ref(path.to_str()?).is_file())
        })?,
    )?;
    table.raw_set(
        "is_dir",
        lua.create_function(|_, path: LuaString| {
            Ok(AsRef::<Path>::as_ref(path.to_str()?).is_dir())
        })?,
    )?;
    table.raw_set(
        "get_file_creation_time",
        lua.create_function(|_, path: LuaString| {
            Ok(std::fs::metadata(path.to_str()?)?
                .created()?
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs())
        })?,
    )?;
    table.raw_set(
        "get_file_modification_time",
        lua.create_function(|_, path: LuaString| {
            Ok(std::fs::metadata(path.to_str()?)?
                .modified()?
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs())
        })?,
    )?;
    table.raw_set(
        "mkdir",
        lua.create_function(|_, path: LuaString| Ok(std::fs::create_dir_all(path.to_str()?)?))?,
    )?;
    table.raw_set(
        "list_dir",
        lua.create_function(|lua, path: LuaString| {
            let table = lua.create_table()?;
            for dir in std::fs::read_dir(path.to_str()?)? {
                let dir = dir?;
                table.raw_push(dir.file_name().to_string_lossy())?;
            }
            Ok(table)
        })?,
    )?;
    table.raw_set(
        "glob",
        lua.create_function(|lua, glob: LuaString| {
            let table = lua.create_table()?;
            for result in glob::glob(glob.to_str()?).map_err(Error::runtime)? {
                table.raw_push(result.map_err(Error::runtime)?.to_string_lossy().as_ref())?;
            }
            Ok(table)
        })?,
    )?;
    table.raw_set(
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
    table.raw_set(
        "get_extensions",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();

            let table = lua.create_table()?;
            for str in str.split('.').skip(1) {
                table.raw_push(str)?;
            }
            Ok(table)
        })?,
    )?;
    table.raw_set(
        "has_extension",
        lua.create_function(|_, (path, extension): (LuaString, LuaString)| {
            let path = path.to_str()?;
            let extension = extension.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();
            Ok(str.split('.').skip(1).any(|x| x == extension))
        })?,
    )?;
    table.raw_set(
        "strip_extensions",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            let str = path.file_name().unwrap().to_string_lossy();
            lua.create_string(str.split('.').next().unwrap())
        })?,
    )?;
    table.raw_set(
        "basename",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);
            lua.create_string(path.file_name().unwrap().to_string_lossy().as_ref())
        })?,
    )?;
    table.raw_set(
        "basename_unix",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            lua.create_string(path.trim_end_matches('/').split('/').last().unwrap_or(""))
        })?,
    )?;
    table.raw_set(
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
    table.raw_set(
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
    table.raw_set(
        "join_path",
        lua.create_function(|lua, (path_a, path_b): (LuaString, LuaString)| {
            let mut path = PathBuf::from(path_a.to_str()?);
            path.push(path_b.to_str()?);
            Ok(lua.create_string(&*path.to_string_lossy())?)
        })?,
    )?;
    table.raw_set(
        "join_path_unix",
        lua.create_function(|_, (path_a, path_b): (LuaString, LuaString)| {
            Ok(format!(
                "{}/{}",
                path_a.to_str()?.trim_end_matches('/'),
                path_b.to_str().unwrap().trim_start_matches('/'),
            ))
        })?,
    )?;
    table.raw_set(
        "split_path",
        lua.create_function(|lua, path: LuaString| {
            let path = path.to_str()?;
            let path = AsRef::<Path>::as_ref(path);

            let table = lua.create_table()?;
            for component in path.components() {
                table.raw_push(lua.create_string(&*component.as_os_str().to_string_lossy())?)?;
            }
            Ok(table)
        })?,
    )?;
    table.raw_set(
        "split_path_unix",
        lua.create_function(|lua, path: LuaString| {
            let table = lua.create_table()?;
            for component in path.to_str()?.split('/').filter(|x| !x.is_empty()) {
                table.raw_push(lua.create_string(component)?)?;
            }
            Ok(table)
        })?,
    )?;
    table.raw_set("is_unix", lua.create_function(|_, ()| Ok(cfg!(unix)))?)?;
    table.raw_set("is_windows", lua.create_function(|_, ()| Ok(cfg!(windows)))?)?;
    table.raw_set(
        "getenv",
        lua.create_function(|lua, (env, default): (LuaString, Value)| {
            match std::env::var(env.to_str()?) {
                Ok(val) => Ok(Value::String(lua.create_string(val)?)),
                Err(_) => Ok(default),
            }
        })?,
    )?;
    table.raw_set(
        "sleep",
        lua.create_function(|_, secs: f64| {
            std::thread::sleep(Duration::from_micros((secs * MICROS).round() as u64));
            Ok(())
        })?,
    )?;

    Ok(table)
}
