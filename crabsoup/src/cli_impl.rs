use crate::CrabsoupLuaContext;
use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::Serialize;

#[derive(Parser)]
#[command(version)]
struct Cli {
    /// Outputs more debugging output.
    ///
    /// One use of this argument turns on `info`, and a second use turns on `debug`, a third use
    /// turns on `trace`, and a fourth use enables debugging output for underlying crates.
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Builds a given webroot.
    Build(BuildArgs),

    /// Starts a REPL for crabsoup.
    Repl {
        /// Enables the deprecated functions available to plugins.
        #[arg(long)]
        plugin: bool,
    },
}

#[derive(Parser, Serialize)]
#[command(version)]
struct BuildArgs {}

pub fn main() -> Result<()> {
    let cli = Cli::parse();

    let env_spec = match cli.verbose {
        // rustyline is never enabled, because holy shit, the REPL is unusable
        0 => "warn,rustyline=info,html5ever=info,selectors=info",
        1 => "info,rustyline=info,html5ever=info,selectors=info",
        2 => "debug,rustyline=info,html5ever=info,selectors=info",
        3 => "trace,rustyline=info,html5ever=info,selectors=info",
        4 => "trace,rustyline=info,html5ever=debug,selectors=debug",
        _ => "trace,rustyline=info",
    };
    tracing_subscriber::FmtSubscriber::builder()
        .with_env_filter(env_spec)
        .init();

    match cli.command {
        Commands::Build(args) => {
            CrabsoupLuaContext::new()?.run_main(args)?;
        }
        Commands::Repl { plugin } => {
            if plugin {
                CrabsoupLuaContext::new()?.repl_in_plugin_env()?;
            } else {
                CrabsoupLuaContext::new()?.repl()?;
            }
        }
    }

    Ok(())
}
