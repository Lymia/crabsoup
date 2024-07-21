use anyhow::Result;
use crabsoup::ctx::CrabsoupLuaContext;

fn main() -> Result<()> {
    tracing_subscriber::FmtSubscriber::builder()
        .with_env_filter("debug,rustyline=info,html5ever=info,selectors=info")
        .init();

    CrabsoupLuaContext::new()?.repl_in_plugin_env()?;
    Ok(())
}
