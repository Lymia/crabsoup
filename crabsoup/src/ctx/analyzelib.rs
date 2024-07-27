use crabsoup_mlua_analyze::{LuaAnalyzer, LuaAnalyzerBuilder};
use mlua::{prelude::LuaString, Lua, Result, Table, UserData, UserDataFields, UserDataRef};
use tracing::{error, warn};

pub fn create_analyze_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    table.raw_set(
        "create",
        lua.create_function(|_, (name, definitions): (LuaString, LuaString)| {
            Ok(Analyzer(
                LuaAnalyzerBuilder::new()
                    .add_definitions(name.to_str()?, definitions.to_str()?)
                    .build(),
            ))
        })?,
    )?;
    table.raw_set(
        "check",
        lua.create_function(
            |_, (analyzer, name, sources): (UserDataRef<Analyzer>, LuaString, LuaString)| {
                let result = analyzer.0.check(name.to_str()?, sources.to_str()?, false);
                for value in &result {
                    let formatted = format!(
                        "{}({}:{}): {}",
                        value.location,
                        value.location_start.line + 1,
                        value.location_start.column,
                        value.message,
                    );
                    if value.is_error {
                        error!(target: "TypeCheck", "{formatted}");
                    } else {
                        warn!(target: "TypeCheck", "{formatted}");
                    }
                }
                Ok(!result.iter().any(|x| x.is_error))
            },
        )?,
    )?;

    Ok(table)
}

struct Analyzer(LuaAnalyzer);
impl UserData for Analyzer {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "Analyzer");
    }
}
