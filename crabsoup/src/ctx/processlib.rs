use mlua::{prelude::LuaString, Error, Lua, Result, Table, UserData, UserDataFields, Value};
use std::process::{Child, Command, Stdio};

enum CommandSource<'a> {
    ShellCommand(LuaString<'a>),
    TableArgs(Vec<LuaString<'a>>),
}

struct CommandInfo {
    command: Command,
    stdin: Option<String>,
}
impl CommandInfo {}

fn parse_command_value(data: &Value) -> Result<(Command, Option<String>)> {
    let shell_command = if let Some(str) = data.as_string() {
        CommandSource::ShellCommand(str.clone())
    } else if let Some(table) = data.as_table() {
        if let Some(str) = table.raw_get::<_, Option<LuaString>>("shell")? {
            CommandSource::ShellCommand(str)
        } else {
            let len = table.raw_len();
            if len == 0 {
                return Err(Error::runtime("No command arguments given."));
            } else {
                let mut vec = Vec::new();
                for arg in table.clone().sequence_values::<LuaString>() {
                    vec.push(arg?);
                }
                CommandSource::TableArgs(vec)
            }
        }
    } else {
        return Err(Error::runtime("Command object must be a string or table."));
    };

    let mut process = match shell_command {
        #[cfg(unix)]
        CommandSource::ShellCommand(cmd) => {
            let mut command = Command::new("sh");
            command.args(["-c", cmd.to_str()?]);
            command
        }

        #[cfg(windows)]
        CommandSource::ShellCommand(cmd) => {
            let mut command = Command::new("cmd");
            command.args(["/C", cmd.to_str()?]);
            command
        }

        #[cfg(not(any(unix, windows)))]
        CommandSource::ShellCommand(cmd) => {
            compile_error!("No processlib implementation for this process!!")
        }

        CommandSource::TableArgs(args) => {
            assert_ne!(args.len(), 0);
            let mut command = Command::new(args[0].to_str()?);
            for arg in args.into_iter().skip(1) {
                command.arg(arg.to_str()?);
            }
            command
        }
    };

    let mut stdin = None;
    if let Some(table) = data.as_table() {
        if let Some(dir) = table.get::<_, Option<LuaString>>("current_directory")? {
            process.current_dir(dir.to_str()?);
        }
        if let Some(env) = table.get::<_, Option<Table>>("env")? {
            for t in env.pairs::<LuaString, LuaString>() {
                let (k, v) = t?;
                process.env(k.to_str()?, v.to_str()?);
            }
        }
        if let Some(dir) = table.get::<_, Option<LuaString>>("stdio")? {
            process.stdin(Stdio::piped());
            stdin = Some(dir.to_str()?.to_string());
        }
    } else {
        process.stdin(Stdio::null());
    }

    Ok((process, stdin))
}

enum LuaProcess {
    RegularProcess(LuaRegularProcess),
}
impl UserData for LuaProcess {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "Process");
    }
}

struct LuaRegularProcess {
    child: Child,
}

pub fn create_process_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    table.raw_set(
        "spawn",
        lua.create_function(|_, info: Value| {
            let child = parse_command_value(&info)?.0.spawn()?;
            Ok(LuaProcess::RegularProcess(LuaRegularProcess { child }))
        })?,
    )?;
    table.raw_set(
        "run",
        lua.create_function(|_, info: Value| {
            let mut child = parse_command_value(&info)?.0.spawn()?;
            if let Some(status) = child.wait()?.code() {
                if status != 0 {
                    Err(Error::runtime(format!("Process has wrong status code: {status}")))
                } else {
                    Ok(())
                }
            } else {
                Err(Error::runtime("Process terminated by signal."))
            }
        })?,
    )?;

    Ok(table)
}
