use crabsoup_mlua_analyze::{LuaAnalyzer, LuaAnalyzerBuilder};
use mlua::{
    prelude::{LuaFunction, LuaString},
    Lua, Result, Table, UserData, UserDataFields, UserDataMethods, UserDataRef,
};
use tracing::{error, warn};

pub fn create_analyze_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    table.raw_set(
        "create",
        lua.create_function(|lua, setup_func: LuaFunction| {
            let builder = LuaAnalyzerBuilder::new();
            let userdata = lua.create_userdata(AnalyzerSetup(builder))?;
            setup_func.call::<_, ()>(&userdata)?;
            let builder = userdata.take::<AnalyzerSetup>()?;
            Ok(Analyzer(builder.0.build()))
        })?,
    )?;
    table.raw_set(
        "check",
        lua.create_function(
            |_, (analyzer, name, sources): (UserDataRef<Analyzer>, LuaString, LuaString)| {
                let result = analyzer.0.check(name.to_str()?, sources.to_str()?, false);
                for value in &result {
                    let location = value.location.as_str();
                    let location = location.strip_suffix(".lua").unwrap_or(location);
                    let location = location.strip_suffix(".luau").unwrap_or(location);
                    let formatted = format!(
                        "{}({}:{}): {}",
                        location,
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

struct AnalyzerSetup(LuaAnalyzerBuilder);
impl UserData for AnalyzerSetup {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "AnalyzerSetup");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method_mut(
            "add_definitions",
            |_, this, (name, source): (LuaString, LuaString)| {
                this.0.add_definitions(name.to_str()?, source.to_str()?);
                Ok(())
            },
        );

        methods.add_method_mut(
            "set_deprecation",
            |_, this, (path, replacement): (LuaString, Option<LuaString>)| {
                let replacement = match &replacement {
                    None => None,
                    Some(s) => Some(s.to_str()?),
                };
                this.0.set_deprecation(path.to_str()?, replacement);
                Ok(())
            },
        );
    }
}

struct Analyzer(LuaAnalyzer);
impl UserData for Analyzer {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "Analyzer");
    }
}
