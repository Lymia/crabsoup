//! Contains raw Lua API invocations.

use mlua::{ffi::*, lua_State, Function, Lua, Result, Table, Value};

pub fn sandbox_global_environment(lua: &Lua) -> Result<()> {
    unsafe extern "C-unwind" fn do_sandbox(lua: *mut lua_State) -> i32 {
        luaL_sandbox(lua, 1);
        0
    }

    unsafe {
        lua.create_c_function(do_sandbox)?.call::<_, ()>(())?;
        Ok(())
    }
}

pub fn clone_env_table<'lua>(lua: &'lua Lua, old_table: Table<'lua>) -> Result<Table<'lua>> {
    let new_table = lua
        .globals()
        .get::<_, Table>("table")?
        .get::<_, Function>("clone")?
        .call::<_, Table>(old_table)?;
    new_table.set("_G", &new_table)?;
    Ok(new_table)
}

pub fn create_sandbox_environment(lua: &Lua, table: Table) -> Result<()> {
    for child in table.clone().pairs::<Value, Value>() {
        let (_, v) = child?;
        if let Some(table) = v.as_table() {
            table.set_readonly(true);
        }
    }
    unsafe {
        unsafe extern "C-unwind" fn do_safeenv(lua: *mut lua_State) -> i32 {
            assert_eq!(lua_gettop(lua), 1);
            lua_setsafeenv(lua, 1, 1);
            0
        }

        let setsafeenv = lua.create_c_function(do_safeenv)?;
        setsafeenv.call::<_, ()>(table)?;
    }
    Ok(())
}

pub fn load_unsafe_functions(lua: &Lua) -> Result<Table> {
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

    unsafe extern "C-unwind" fn deoptimize_env(lua: *mut lua_State) -> i32 {
        // signature: (env)
        luaL_checktype(lua, 1, LUA_TTABLE);
        lua_setsafeenv(lua, 1, 0);
        0
    }

    let table = lua.create_table()?;
    unsafe {
        table.set("load_in_new_thread", lua.create_c_function(load_in_new_thread)?)?;
        table.set("deoptimize_env", lua.create_c_function(deoptimize_env)?)?;
    }
    Ok(table)
}
