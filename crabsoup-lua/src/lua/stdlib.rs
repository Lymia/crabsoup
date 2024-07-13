use mlua::{prelude::LuaString, Error, UserData, UserDataFields, UserDataMethods, Value};
use rustyline::{error::ReadlineError, DefaultEditor};
use std::borrow::Cow;
use tracing::{debug, error, info, trace, warn};

pub struct CrabSoupLib;
impl UserData for CrabSoupLib {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "CrabSoupLib");
        fields
            .add_field("_VERSION", concat!(env!("CARGO_PKG_NAME"), " ", env!("CARGO_PKG_VERSION")));
        fields.add_field("VERSION_ONLY", env!("CARGO_PKG_VERSION"));
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_function("open_rustyline", |_, ()| {
            let editor = DefaultEditor::new().map_err(Error::runtime)?;
            Ok(RustyLineEditor { editor })
        });

        methods.add_function(
            "loadstring",
            |lua, (code, chunkname, env): (LuaString, Option<LuaString>, Option<Value>)| {
                let mut chunk = lua.load(code.to_str()?);
                if let Some(chunkname) = chunkname {
                    chunk = chunk.set_name(chunkname.to_str()?);
                } else {
                    let code_name = code.to_str()?;
                    let final_name = if code_name.chars().count() > 40 {
                        let mut str: String = code_name.chars().take(40).collect();
                        str.push_str("...");
                        Cow::Owned(str)
                    } else {
                        Cow::Borrowed(code_name)
                    };
                    chunk = chunk.set_name(final_name);
                }
                if let Some(env) = env {
                    chunk = chunk.set_environment(env);
                }
                match chunk.into_function() {
                    Ok(func) => Ok((Some(func), None)),
                    Err(Error::SyntaxError { message, .. }) => Ok((None, Some(message))),
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

        methods.add_function("plugin_fail", |_, str: LuaString| {
            Ok(PluginInstruction::Fail(str.to_str()?.to_string()))
        });
        methods.add_function("plugin_exit", |_, str: LuaString| {
            Ok(PluginInstruction::Exit(str.to_str()?.to_string()))
        });
    }
}

enum PluginInstruction {
    Fail(String),
    Exit(String),
}
impl UserData for PluginInstruction {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "PluginInstruction");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("get_message", |lua, this, ()| match this {
            PluginInstruction::Fail(msg) => Ok(lua.create_string(msg)),
            PluginInstruction::Exit(msg) => Ok(lua.create_string(msg)),
        });

        methods.add_method("is_fail", |_, this, ()| match this {
            PluginInstruction::Fail(_) => Ok(true),
            _ => Ok(false),
        });
        methods.add_method("is_exit", |_, this, ()| match this {
            PluginInstruction::Exit(_) => Ok(true),
            _ => Ok(false),
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
