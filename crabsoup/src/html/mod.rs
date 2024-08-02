use anyhow::Result;
use kuchikiki::NodeRef;
use tidier::{FormatOptions, Indent, LineEnding};

pub mod extract_text;
pub mod is_document;

pub fn pretty_print(text: &str) -> Result<String> {
    let opts = FormatOptions {
        indent: Indent::DEFAULT,
        eol: LineEnding::Lf,
        wrap: 120,
        join_classes: true,
        join_styles: true,
        ..FormatOptions::DEFAULT
    };
    Ok(tidier::format(text, false, &opts)?)
}

pub fn clone_node(node: &NodeRef) -> NodeRef {
    let data = node.0.data().clone();
    let new_node = NodeRef::new(data);

    for child in node.children() {
        new_node.append(clone_node(&child));
    }

    new_node
}
