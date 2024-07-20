use anyhow::Result;
use crabsoup::lua::CrabsoupLuaContext;

fn main() -> Result<()> {
    CrabsoupLuaContext::new()?.repl_in_plugin_env()?;
    Ok(())
}
