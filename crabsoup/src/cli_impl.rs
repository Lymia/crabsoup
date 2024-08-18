use crate::CrabsoupLuaContext;
use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::Serialize;
use std::path::PathBuf;

#[derive(Parser)]
#[command(version)]
struct Cli {
    /// Outputs more debugging output.
    ///
    /// One use of this argument turns on `debug`, a second use turns on `trace`, and a third use
    /// enables debugging output for underlying crates.
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,

    /// Outputs less debugging output.
    ///
    /// One use of this argument disables `info`, and a second use disables `warn`.
    #[arg(short, long, action = clap::ArgAction::Count)]
    quiet: u8,

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
struct BuildArgs {
    #[arg(short, long)]
    config: Option<PathBuf>,
}

pub fn main() -> Result<()> {
    let cli = Cli::parse();

    let env_spec = match (cli.verbose, cli.quiet) {
        // rustyline is never enabled, because holy shit, the REPL is unusable
        (0, 2) => "error",
        (0, 1) => "warn",
        (0, 0) => "info",
        (1, 0) => "debug,rustyline=info,html5ever=info,selectors=info",
        (2, 0) => "trace,rustyline=info,html5ever=info,selectors=info",
        (3, 0) => "trace,rustyline=info,html5ever=debug,selectors=debug",
        _ => panic!("Wrong number of -v and -q?"), // TODO: Better error
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
