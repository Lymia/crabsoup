use anyhow::Result;
use crabsoup_lua::lua::CrabsoupLuaContext;

fn main() -> Result<()> {
    CrabsoupLuaContext::new()?.repl()?;

    Ok(())
}
