use anyhow::Result;
use mlua::Compiler;
use std::path::PathBuf;

fn compile_script(input: &[u8]) -> Vec<u8> {
    let compiler = Compiler::new()
        .set_optimization_level(2)
        .set_type_info_level(1);
    compiler.compile(input)
}

pub fn main() -> Result<()> {
    let mut out_path = PathBuf::from(std::env::var("OUT_DIR")?);
    out_path.push("luau_compiled");
    std::fs::create_dir_all(&out_path)?;

    let mut all_paths = Vec::new();

    for path in glob::glob("lua/**/*")? {
        let path = path?;
        let file_name = path.file_name().unwrap().to_string_lossy();
        if path.is_file() && (file_name.ends_with(".lua") || file_name.ends_with(".luau")) {
            let suffix = path.strip_prefix("lua/")?;
            let mut output = out_path.clone();
            output.push(suffix);

            let mut parent = output.clone();
            parent.pop();
            std::fs::create_dir_all(parent)?;
            std::fs::write(&output, compile_script(&std::fs::read(&path)?))?;

            all_paths.push((
                path.to_string_lossy()
                    .strip_prefix("lua/")
                    .unwrap()
                    .to_string(),
                output.to_string_lossy().to_string(),
            ));
        }
        println!("cargo::rerun-if-changed={}", path.display());
    }

    out_path.pop();
    out_path.push("luau_modules.rs");

    let mut push_lines = Vec::new();
    for (k, v) in all_paths {
        push_lines.push(format!(r#"map.insert({k:?}, include_bytes!({v:?}).as_slice());"#));
    }
    let push_lines = push_lines.join("\n");
    std::fs::write(
        out_path,
        format!(
            r#"
                fn load_lua_sources() -> crate::wyhash::WyHashMap<&'static str, &'static [u8]> {{
                    let mut map = crate::wyhash::WyHashMap::default();
                    {push_lines}
                    map
                }}
            "#
        ),
    )?;

    Ok(())
}
