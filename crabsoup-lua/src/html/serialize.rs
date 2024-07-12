use anyhow::Result;
use ego_tree::{iter::Edge, NodeId, NodeRef};
use html5ever::{
    serialize::{AttrRef, Serialize, SerializeOpts, Serializer, TraversalScope},
    QualName,
};
use scraper::{Html, Node};
use std::result::Result as StdResult;

/// Code copied from `scraper` crate.
fn serialize<S: Serializer>(
    self_node: NodeRef<Node>,
    serializer: &mut S,
    traversal_scope: TraversalScope,
) -> StdResult<(), std::io::Error> {
    for edge in self_node.traverse() {
        match edge {
            Edge::Open(node) => {
                if node == self_node && traversal_scope == TraversalScope::ChildrenOnly(None) {
                    continue;
                }

                match *node.value() {
                    Node::Doctype(ref doctype) => {
                        serializer.write_doctype(doctype.name())?;
                    }
                    Node::Comment(ref comment) => {
                        serializer.write_comment(comment)?;
                    }
                    Node::Text(ref text) => {
                        serializer.write_text(text)?;
                    }
                    Node::Element(ref elem) => {
                        let attrs = elem.attrs.iter().map(|(k, v)| (k, &v[..]));
                        serializer.start_elem(elem.name.clone(), attrs)?;
                    }
                    _ => (),
                }
            }

            Edge::Close(node) => {
                if node == self_node && traversal_scope == TraversalScope::ChildrenOnly(None) {
                    continue;
                }

                if let Some(elem) = node.value().as_element() {
                    serializer.end_elem(elem.name.clone())?;
                }
            }
        }
    }

    Ok(())
}

#[derive(Default)]
struct InnerTextSerializer {
    text: String,
    skip_levels: usize,
    trailing_whitespace: bool,
}
impl Serializer for InnerTextSerializer {
    fn start_elem<'a, AttrIter>(&mut self, name: QualName, attrs: AttrIter) -> std::io::Result<()>
    where AttrIter: Iterator<Item = AttrRef<'a>> {
        if self.skip_levels == 0 {
            if name.local.eq_str_ignore_ascii_case("head")
                || name.local.eq_str_ignore_ascii_case("style")
                || name.local.eq_str_ignore_ascii_case("script")
            {
                self.skip_levels = 1;
            }
        } else {
            self.skip_levels += 1;
        }
        Ok(())
    }

    fn end_elem(&mut self, name: QualName) -> std::io::Result<()> {
        if self.skip_levels != 0 {
            self.skip_levels -= 1;
        }
        Ok(())
    }

    fn write_text(&mut self, text: &str) -> std::io::Result<()> {
        if self.skip_levels != 0 {
            return Ok(());
        }

        let striped_start = text.trim_start();
        let has_leading_whitespace = striped_start.len() != text.len();
        let stripped = striped_start.trim_start();
        let has_trailing_whitespace = stripped.len() != striped_start.len();

        if has_leading_whitespace && !self.trailing_whitespace && !self.text.is_empty() {
            self.text.push_str(" ");
        }
        if !stripped.is_empty() {
            self.trailing_whitespace = false;
            self.text.push_str(stripped);

            if has_trailing_whitespace {
                self.text.push_str(" ");
                self.trailing_whitespace = true;
            }
        }

        Ok(())
    }

    fn write_comment(&mut self, text: &str) -> std::io::Result<()> {
        Ok(())
    }

    fn write_doctype(&mut self, name: &str) -> std::io::Result<()> {
        Ok(())
    }

    fn write_processing_instruction(&mut self, target: &str, data: &str) -> std::io::Result<()> {
        Ok(())
    }
}

pub fn to_inner_text(html: &Html, node: NodeId) -> Result<String> {
    let mut serializer = InnerTextSerializer::default();
    serialize(html.tree.get(node).unwrap(), &mut serializer, TraversalScope::IncludeNode)?;
    Ok(serializer.text.trim().to_string())
}

pub fn serialize_from_node(
    html: &Html,
    node: NodeId,
    traversal_scope: TraversalScope,
) -> Result<String> {
    struct SerializeMapper<'a>(NodeRef<'a, Node>);
    impl<'a> Serialize for SerializeMapper<'a> {
        fn serialize<S>(
            &self,
            serializer: &mut S,
            traversal_scope: TraversalScope,
        ) -> std::io::Result<()>
        where
            S: Serializer,
        {
            serialize(self.0.clone(), serializer, traversal_scope)
        }
    }

    let opts =
        SerializeOpts { scripting_enabled: false, traversal_scope, create_missing_parent: false };

    let mut buf = Vec::new();
    let node = html.tree.get(node).unwrap();
    html5ever::serialize(&mut buf, &SerializeMapper(node), opts)?;
    Ok(String::from_utf8(buf).unwrap())
}
