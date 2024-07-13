use mlua::{prelude::LuaString, Error, UserData, UserDataMethods};
use rustyline::DefaultEditor;

pub struct CrabSoupLib;
impl UserData for CrabSoupLib {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_function("open_rustyline", |_, ()| {
            Ok(RustyLineLibrary { editor: DefaultEditor::new().map_err(Error::runtime)? })
        });
        methods.add_function("loadstring", |lua, (chunk, chunkname): (LuaString, Option<LuaString>)| {
            let mut chunk = lua.load(chunk.to_str()?);
            if let Some(chunkname) = chunkname {
                chunk = chunk.set_name(chunkname.to_str()?);
            }
            Ok(chunk.into_function()?)
        })
    }
}

struct RustyLineLibrary {
    editor: DefaultEditor,
}
impl UserData for RustyLineLibrary {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method_mut("readline", |_, this, prompt: LuaString| {
            Ok(this
                .editor
                .readline(prompt.to_str()?)
                .map_err(Error::runtime)?)
        });
    }
}
