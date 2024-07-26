use crabsoup_mlua_analyze::LuaAnalyzerBuilder;

fn main() {
    let analyzer = LuaAnalyzerBuilder::new()
        .add_definitions("@crabsoup", include_str!("../../crabsoup/lua/defs/standalone_ctx.d_lua"))
        .build();
    println!("{:#?}", analyzer.check("test.lua", "print(_CRABSOUP_VERSION + 3)", false));
}
