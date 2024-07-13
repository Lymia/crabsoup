use mlua::{prelude::LuaString, Error, UserData, UserDataFields, UserDataMethods, Value};
use rustyline::{error::ReadlineError, DefaultEditor};
use tracing::{debug, error, info, trace, warn};

pub struct CrabSoupLib;
impl UserData for CrabSoupLib {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "CrabSoupLib");
        fields
            .add_field("_VERSION", concat!(env!("CARGO_PKG_NAME"), " ", env!("CARGO_PKG_VERSION")));
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_function("open_rustyline", |_, ()| {
            let editor = DefaultEditor::new().map_err(Error::runtime)?;
            Ok(RustyLineEditor { editor })
        });

        methods.add_function(
            "loadstring",
            |lua, (chunk, chunkname, env): (LuaString, Option<LuaString>, Option<Value>)| {
                let mut chunk = lua.load(chunk.to_str()?);
                if let Some(chunkname) = chunkname {
                    chunk = chunk.set_name(chunkname.to_str()?);
                }
                if let Some(env) = env {
                    chunk = chunk.set_environment(env);
                }
                match chunk.into_function() {
                    Ok(func) => Ok((Some(func), None)),
                    Err(e) => Ok((None, Some(e.to_string()))),
                }
            },
        );

        methods.add_function("error", |_, str: LuaString| {
            error!("{}", str.to_str()?);
            Ok(())
        });
        methods.add_function("warn", |_, str: LuaString| {
            warn!("{}", str.to_str()?);
            Ok(())
        });
        methods.add_function("info", |_, str: LuaString| {
            info!("{}", str.to_str()?);
            Ok(())
        });
        methods.add_function("debug", |_, str: LuaString| {
            debug!("{}", str.to_str()?);
            Ok(())
        });
        methods.add_function("trace", |_, str: LuaString| {
            trace!("{}", str.to_str()?);
            Ok(())
        });
    }
}

struct RustyLineEditor {
    editor: DefaultEditor,
}
impl UserData for RustyLineEditor {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "RustyLineEditor");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method_mut("readline", |_, this, prompt: LuaString| {
            match this.editor.readline(prompt.to_str()?) {
                Ok(line) => Ok(Some(line)),
                Err(ReadlineError::Interrupted) => Ok(None),
                Err(ReadlineError::Eof) => Ok(None),
                Err(e) => Err(Error::runtime(e)),
            }
        });

        methods.add_method_mut("saveline", |_, this, line: LuaString| {
            this.editor
                .add_history_entry(line.to_str()?)
                .map_err(Error::runtime)?;
            Ok(())
        });
    }
}
