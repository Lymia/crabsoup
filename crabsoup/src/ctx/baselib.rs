use mlua::{
    ffi::{
        luaL_checktype, luaL_sandbox, luaL_sandboxthread, lua_getfenv, lua_mainthread,
        lua_newthread, lua_pushglobaltable, lua_replace, lua_rotate, lua_setfenv, lua_setsafeenv,
        lua_xmove, LUA_GLOBALSINDEX, LUA_TFUNCTION, LUA_TTABLE,
    },
    lua_State,
    prelude::LuaString,
    ChunkMode, Error, Lua, MultiValue, Result, Table, UserData, UserDataFields, UserDataMethods,
    Value,
};
use rustyline::{error::ReadlineError, DefaultEditor};
use std::borrow::Cow;
use tracing::{debug, error, info, trace, warn};

pub fn create_base_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    {
        let version = concat!(env!("CARGO_PKG_NAME"), " ", env!("CARGO_PKG_VERSION"));
        table.set("_VERSION", version)?;
        table.set("VERSION_ONLY", env!("CARGO_PKG_VERSION"))?;
    }

    table.set(
        "open_rustyline",
        lua.create_function(|_, ()| {
            let editor = DefaultEditor::new().map_err(Error::runtime)?;
            Ok(RustyLineEditor { editor })
        })?,
    )?;

    table.set(
        "loadstring_rt",
        lua.create_function(|lua, (code, chunkname): (LuaString, LuaString)| {
            Ok(lua
                .load(code.as_bytes())
                .set_mode(ChunkMode::Binary)
                .set_name(chunkname.to_str()?)
                .into_function()?)
        })?,
    )?;

    table.set(
        "loadstring",
        lua.create_function(
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
        )?,
    )?;

    table.set("is_nan", lua.create_function(|_, f: f64| Ok(f.is_nan()))?)?;
    table.set("is_inf", lua.create_function(|_, f: f64| Ok(f.is_infinite()))?)?;
    table.set("is_finite", lua.create_function(|_, f: f64| Ok(f.is_finite()))?)?;

    fn target(lua: &Lua) -> Result<Cow<'static, str>> {
        if let Some(debug) = lua.inspect_stack(1) {
            if let Some(source) = debug.source().source {
                if source.starts_with("@") {
                    let source = source.strip_suffix(".lua").unwrap_or(&source);
                    let source = source.strip_suffix(".luau").unwrap_or(&source);
                    Ok(source.to_string().into())
                } else {
                    Ok("<loadstring>".into())
                }
            } else {
                Ok(module_path!().into())
            }
        } else {
            Ok(module_path!().into())
        }
    }
    fn value_to_str(value: &MultiValue) -> Result<String> {
        let mut values = String::new();
        for value in value.iter() {
            if !values.is_empty() {
                values.push('\t');
            }
            values.push_str(&value.to_string()?);
        }
        Ok(values)
    }
    table.set(
        "error",
        lua.create_function(|lua, value: MultiValue| {
            let target_str = target(lua)?;
            error!(target: "Lua", "{target_str}: {}", value_to_str(&value)?);
            Ok(())
        })?,
    )?;
    table.set(
        "warn",
        lua.create_function(|lua, value: MultiValue| {
            let target_str = target(lua)?;
            warn!(target: "Lua", "{target_str}: {}", value_to_str(&value)?);
            Ok(())
        })?,
    )?;
    table.set(
        "info",
        lua.create_function(|lua, value: MultiValue| {
            let target_str = target(lua)?;
            info!(target: "Lua", "{target_str}: {}", value_to_str(&value)?);
            Ok(())
        })?,
    )?;
    table.set(
        "debug",
        lua.create_function(|lua, value: MultiValue| {
            let target_str = target(lua)?;
            debug!(target: "Lua", "{target_str}: {}", value_to_str(&value)?);
            Ok(())
        })?,
    )?;
    table.set(
        "trace",
        lua.create_function(|lua, value: MultiValue| {
            let target_str = target(lua)?;
            trace!(target: "Lua", "{target_str}: {}", value_to_str(&value)?);
            Ok(())
        })?,
    )?;

    table.set(
        "plugin_fail",
        lua.create_function(|_, str: LuaString| {
            Ok(PluginInstruction::Fail(str.to_str()?.to_string()))
        })?,
    )?;
    table.set(
        "plugin_exit",
        lua.create_function(|_, str: LuaString| {
            Ok(PluginInstruction::Exit(str.to_str()?.to_string()))
        })?,
    )?;

    table.set(
        "raw_setmetatable",
        lua.create_function(|_, (table, metatable): (Table, Option<Table>)| {
            table.set_metatable(metatable);
            Ok(())
        })?,
    )?;
    table.set(
        "raw_getmetatable",
        lua.create_function(|_, table: Table| Ok(table.get_metatable()))?,
    )?;
    table.set(
        "raw_freeze",
        lua.create_function(|_, table: Table| {
            table.set_readonly(true);
            Ok(())
        })?,
    )?;

    load_unsafe_functions(lua, &table)?;

    Ok(table)
}

fn load_unsafe_functions(lua: &Lua, table: &Table) -> Result<()> {
    unsafe extern "C-unwind" fn load_in_new_thread(lua: *mut lua_State) -> i32 {
        // signature: (loader, env) -> thread
        luaL_checktype(lua, 1, LUA_TFUNCTION);
        luaL_checktype(lua, 2, LUA_TTABLE);

        // Transfer all arguments to the main Lua thread.
        let lua_main = lua_mainthread(lua);
        let lua_thread = lua_newthread(lua_main);
        lua_rotate(lua, -3, 1);
        lua_xmove(lua, lua_thread, 2);

        // Creates the new thread
        lua_replace(lua_thread, LUA_GLOBALSINDEX);
        luaL_sandboxthread(lua_thread);
        // (loader function is left on stack here)

        // Pushes the newly created thread to the `lua` thread
        if lua != lua_main {
            lua_xmove(lua_main, lua, 1);
        }
        1
    }

    unsafe extern "C-unwind" fn set_safeenv_flag(lua: *mut lua_State) -> i32 {
        // signature: (env)
        luaL_checktype(lua, 1, LUA_TTABLE);
        lua_setsafeenv(lua, 1, 1);
        0
    }

    unsafe extern "C-unwind" fn deoptimize_env(lua: *mut lua_State) -> i32 {
        // signature: (env)
        luaL_checktype(lua, 1, LUA_TTABLE);
        lua_setsafeenv(lua, 1, 0);
        0
    }

    unsafe extern "C-unwind" fn get_globals(lua: *mut lua_State) -> i32 {
        lua_pushglobaltable(lua);
        1
    }

    unsafe extern "C-unwind" fn set_globals(lua: *mut lua_State) -> i32 {
        // signature: (env)
        luaL_checktype(lua, 1, LUA_TTABLE);
        lua_replace(lua, LUA_GLOBALSINDEX);
        0
    }

    unsafe extern "C-unwind" fn raw_getfenv(lua: *mut lua_State) -> i32 {
        // signature: (function) -> env
        luaL_checktype(lua, 1, LUA_TFUNCTION);
        lua_getfenv(lua, 1);
        1
    }

    unsafe extern "C-unwind" fn raw_setfenv(lua: *mut lua_State) -> i32 {
        // signature: (function, env)
        luaL_checktype(lua, 1, LUA_TFUNCTION);
        luaL_checktype(lua, 2, LUA_TTABLE);
        lua_setfenv(lua, 1);
        0
    }

    unsafe extern "C-unwind" fn do_sandbox(lua: *mut lua_State) -> i32 {
        luaL_sandbox(lua, 1);
        0
    }

    unsafe {
        table.set("load_in_new_thread", lua.create_c_function(load_in_new_thread)?)?;
        table.set("set_safeenv_flag", lua.create_c_function(set_safeenv_flag)?)?;
        table.set("deoptimize_env", lua.create_c_function(deoptimize_env)?)?;
        table.set("get_globals", lua.create_c_function(get_globals)?)?;
        table.set("set_globals", lua.create_c_function(set_globals)?)?;
        table.set("raw_getfenv", lua.create_c_function(raw_getfenv)?)?;
        table.set("raw_setfenv", lua.create_c_function(raw_setfenv)?)?;
        table.set("do_sandbox", lua.create_c_function(do_sandbox)?)?;
    }

    Ok(())
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
