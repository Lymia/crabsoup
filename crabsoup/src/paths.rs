use mlua::{prelude::LuaString, Error, Lua, Result};
use std::path::{Path, PathBuf};
use typed_path::{
    NativePath, Utf8NativeEncoding, Utf8NativePath, Utf8UnixEncoding, Utf8UnixPath, Utf8UnixPathBuf,
};

type StandardPath = Utf8UnixPath;
type StandardPathBuf = Utf8UnixPathBuf;
type StandardEncoding = Utf8UnixEncoding;

pub fn lstr_to_system_path(path: LuaString) -> Result<PathBuf> {
    let path = StandardPath::new(path.to_str()?);
    let native = path.with_encoding::<Utf8NativeEncoding>();
    if native.is_absolute() {
        Err(Error::runtime("Absolute paths are not allowed in crabsoup."))
    } else {
        Ok(native.into())
    }
}

pub fn lstr_to_path<'lua>(path: &'lua LuaString) -> Result<&'lua StandardPath> {
    let str = path.to_str()?;
    Ok(StandardPath::new(str))
}

pub fn system_path_to_path(path: &Path) -> Result<StandardPathBuf> {
    let path =
        Utf8NativePath::from_bytes_path(NativePath::new(path.as_os_str().as_encoded_bytes()))
            .map_err(Error::runtime)?;
    Ok(path.with_encoding::<StandardEncoding>())
}

pub fn system_path_to_lstr<'lua>(lua: &'lua Lua, path: &Path) -> Result<LuaString<'lua>> {
    let standard = system_path_to_path(path)?;
    lua.create_string(standard.as_str())
}

pub fn basename(path: &StandardPath) -> Result<&str> {
    if let Some(name) = path.file_name() {
        Ok(name)
    } else {
        Err(Error::runtime("Path must not end in a relative path component"))
    }
}

pub fn dirname(path: &StandardPath) -> Result<&str> {
    if let Some(parent) = path.parent() {
        Ok(parent.as_str())
    } else {
        Err(Error::runtime("Path must have a parent directory"))
    }
}
