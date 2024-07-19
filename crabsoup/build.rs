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

    for path in glob::glob("lua/**/*")? {
        let path = path?;
        if path.is_file() {
            let suffix = path.strip_prefix("lua/")?;
            let mut output = out_path.clone();
            output.push(suffix);

            let mut parent = output.clone();
            parent.pop();
            std::fs::create_dir_all(parent)?;
            std::fs::write(output, compile_script(&std::fs::read(&path)?))?;

            println!("cargo::rerun-if-changed={}", path.display());
        }
    }

    Ok(())
}
