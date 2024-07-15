//! Contains raw Lua API invocations.

use mlua::{
    ffi::{
        luaL_sandbox, luaL_sandboxthread, lua_gettop, lua_isnil, lua_mainthread, lua_newthread,
        lua_pop, lua_replace, lua_setsafeenv, lua_xmove, LUA_GLOBALSINDEX,
    },
    lua_State, Function, Lua, Result, Table, Thread, Value,
};

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
    let new_table = lua.globals()
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

pub fn create_new_thread<'lua>(
    lua: &'lua Lua,
    env: Option<Table<'lua>>,
    loader: Function<'lua>,
) -> Result<Thread<'lua>> {
    unsafe extern "C-unwind" fn loader_wrapper_function(lua: *mut lua_State) -> i32 {
        // signature: (loader, env) -> thread

        // Transfer all arguments to the main Lua thread.
        let lua_main = lua_mainthread(lua);
        let lua_thread = lua_newthread(lua_main);
        lua_xmove(lua, lua_thread, 2);

        // Creates the new thread
        if lua_isnil(lua_thread, -1) == 0 {
            lua_replace(lua_thread, LUA_GLOBALSINDEX);
        } else {
            lua_pop(lua_thread, 1);
        }
        luaL_sandboxthread(lua);

        // Pushes the newly created thread to the `lua` thread
        if lua != lua_main {
            lua_xmove(lua_main, lua, 1);
        }
        1
    }

    unsafe {
        let func = lua.create_c_function(loader_wrapper_function)?;
        Ok(func.call::<_, Thread>((loader, env))?)
    }
}
