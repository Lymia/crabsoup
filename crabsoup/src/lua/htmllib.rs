use crate::html_is_root::is_document;
use encoding_rs::{Encoding, UTF_8};
use html5ever::{namespace_url, ns, LocalName, QualName};
use kuchikiki::{
    parse_fragment, parse_html, traits::TendrilSink, ElementData, NodeDataRef, NodeRef, Selectors,
};
use mlua::{prelude::LuaString, Error, Lua, Result, Table, UserData, UserDataFields, UserDataRef};
use std::{cell::RefCell, io::Cursor, rc::Rc};
use tracing::warn;

fn qual_name(name: &str) -> QualName {
    QualName { prefix: None, ns: ns!(html), local: LocalName::from(name) }
}
fn decode_encoding(encoding: &LuaString) -> Result<&'static Encoding> {
    match Encoding::for_label(encoding.as_bytes()) {
        None => {
            Err(Error::runtime(format_args!("Unknown encoding: {}", encoding.to_string_lossy())))
        }
        Some(encoding) => Ok(encoding),
    }
}
fn encoding_warning(lua: &Lua, encoding: &'static Encoding, encode: bool) {
    let location = if let Some(source) = lua.inspect_stack(1) {
        source
            .source()
            .source
            .map(|x| x.to_string())
            .unwrap_or_else(|| "<unknown>".to_string())
    } else {
        "<unknown>".to_string()
    };
    if encode {
        warn!("{location}: Encountered invalid {} while serializing HTML.", encoding.name());
    } else {
        warn!("{location}: Encountered invalid {} while parsing HTML.", encoding.name());
    }
}
fn html_to_string<'lua>(
    lua: &'lua Lua,
    node: &NodeRef,
    encoding: &Option<LuaString>,
    active_encoding_ref: &Rc<RefCell<&'static Encoding>>,
    pretty_print: bool,
) -> Result<LuaString<'lua>> {
    let encoding = match encoding {
        None => *active_encoding_ref.borrow(),
        Some(encoding) => decode_encoding(&encoding)?,
    };

    let mut data = Vec::new();
    node.serialize(&mut Cursor::new(&mut data))?;
    let rust_str = std::str::from_utf8(&data)?;
    let (text, encoding, errors) = encoding.encode(if pretty_print {
        warn!("Pretty printing is not currently implemented.");
        rust_str
    } else {
        rust_str
    });
    if errors {
        encoding_warning(lua, encoding, true);
    }
    Ok(lua.create_string(&text)?)
}
fn element(node: &NodeRef) -> Result<NodeDataRef<ElementData>> {
    match node.clone().into_element_ref() {
        None => Err(Error::runtime("This function may only be called on HTML elements.")),
        Some(elem) => Ok(elem),
    }
}

pub fn create_html_table(lua: &Lua) -> Result<Table> {
    let table = lua.create_table()?;

    let active_encoding = Rc::new(RefCell::new(UTF_8));

    // Parsing and rendering
    {
        let active_encoding_ref = active_encoding.clone();
        table.set(
            "parse",
            lua.create_function(move |lua, (text, encoding): (LuaString, Option<LuaString>)| {
                let encoding = match encoding {
                    None => *active_encoding_ref.borrow(),
                    Some(encoding) => decode_encoding(&encoding)?,
                };
                let (text, encoding, errors) = encoding.decode(text.as_bytes());
                if errors {
                    encoding_warning(lua, encoding, false);
                }
                if is_document(&text) {
                    Ok(LuaNodeRef(parse_html().one(&*text)))
                } else {
                    let fragment = parse_fragment(qual_name("section"), vec![]).one(&*text);
                    let new_root = NodeRef::new_document();
                    assert_eq!(fragment.children().count(), 1);
                    for child in fragment.children().next().unwrap().children() {
                        new_root.append(child);
                    }
                    Ok(LuaNodeRef(new_root))
                }
            })?,
        )?;
    }
    {
        let active_encoding_ref = active_encoding.clone();
        table.set(
            "set_default_encoding",
            lua.create_function(move |_, encoding: LuaString| {
                *active_encoding_ref.borrow_mut() = decode_encoding(&encoding)?;
                Ok(())
            })?,
        )?;
    }
    {
        let active_encoding_ref = active_encoding.clone();
        table.set(
            "to_string",
            lua.create_function(
                move |lua, (node_ref, encoding): (UserDataRef<LuaNodeRef>, Option<LuaString>)| {
                    html_to_string(lua, &node_ref.0, &encoding, &active_encoding_ref, false)
                },
            )?,
        )?;
    }
    {
        let active_encoding_ref = active_encoding.clone();
        table.set(
            "pretty_print",
            lua.create_function(
                move |lua, (node_ref, encoding): (UserDataRef<LuaNodeRef>, Option<LuaString>)| {
                    html_to_string(lua, &node_ref.0, &encoding, &active_encoding_ref, true)
                },
            )?,
        )?;
    }

    // Node creation
    table.set(
        "create_document",
        lua.create_function(|_, ()| Ok(LuaNodeRef(NodeRef::new_document())))?,
    )?;
    table.set(
        "create_element",
        lua.create_function(|_, (name, text): (LuaString, Option<LuaString>)| {
            let elem = NodeRef::new_element(qual_name(name.to_str()?), vec![]);
            if let Some(text) = text {
                elem.append(NodeRef::new_text(text.to_str()?));
            }
            Ok(LuaNodeRef(elem))
        })?,
    )?;
    table.set(
        "create_text",
        lua.create_function(|_, text: LuaString| {
            Ok(LuaNodeRef(NodeRef::new_text(text.to_str()?)))
        })?,
    )?;

    // Selection and selector match checking
    // - Implemented in Lua: HTML.select_any_of - note: crabsoup uses selector lists
    // - Implemented in Lua: HTML.select_all_of - note: crabsoup uses selector lists
    // - Implemented in Lua: HTML.matches_any_of_selectors - note: crabsoup uses selector lists
    table.set(
        "select",
        lua.create_function(|lua, (html, selector): (UserDataRef<LuaNodeRef>, LuaString)| {
            let table = lua.create_table()?;
            for elem in html
                .0
                .select(selector.to_str()?)
                .map_err(|()| Error::runtime("Could not parse selector."))?
            {
                table.push(LuaNodeRef(elem.as_node().clone()))?;
            }
            Ok(table)
        })?,
    )?;
    table.set(
        "select_one",
        lua.create_function(|_, (html, selector): (UserDataRef<LuaNodeRef>, LuaString)| {
            Ok(html
                .0
                .select(selector.to_str()?)
                .map_err(|()| Error::runtime("Could not parse selector."))?
                .next()
                .map(|x| LuaNodeRef(x.as_node().clone())))
        })?,
    )?;
    table.set(
        "matches_selector",
        lua.create_function(|_, (node, selector): (UserDataRef<LuaNodeRef>, LuaString)| {
            let selectors = Selectors::compile(selector.to_str()?)
                .map_err(|()| Error::runtime("Could not parse selector."))?;
            if let Some(elem) = node.0.clone().into_element_ref() {
                Ok(selectors.matches(&elem))
            } else {
                Ok(false)
            }
        })?,
    )?;

    // Access to element tree surroundings
    table.set(
        "parent",
        lua.create_function(|_, node: UserDataRef<LuaNodeRef>| {
            Ok(node.0.parent().map(LuaNodeRef))
        })?,
    )?;
    table.set(
        "children",
        lua.create_function(|lua, node: UserDataRef<LuaNodeRef>| {
            let table = lua.create_table()?;
            for node in node.0.children() {
                table.push(LuaNodeRef(node))?;
            }
            Ok(table)
        })?,
    )?;
    table.set(
        "ancestors",
        lua.create_function(|lua, node: UserDataRef<LuaNodeRef>| {
            let table = lua.create_table()?;
            for node in node.0.ancestors() {
                table.push(LuaNodeRef(node))?;
            }
            Ok(table)
        })?,
    )?;
    table.set(
        "descendants",
        lua.create_function(|lua, node: UserDataRef<LuaNodeRef>| {
            let table = lua.create_table()?;
            for node in node.0.descendants() {
                table.push(LuaNodeRef(node))?;
            }
            Ok(table)
        })?,
    )?;
    // TODO: HTML.siblings after figuring out what EXACTLY it does
    table.set(
        "child_count",
        lua.create_function(|_, node: UserDataRef<LuaNodeRef>| Ok(node.0.children().count()))?,
    )?;
    table.set(
        "is_empty",
        lua.create_function(|_, node: UserDataRef<LuaNodeRef>| {
            Ok(node.0.children().next().is_none())
        })?,
    )?;

    // Element property access and manipulation
    // - Implemented in Lua: HTML.append_attribute
    table.set(
        "get_tag_name",
        lua.create_function(|_, node: UserDataRef<LuaNodeRef>| {
            Ok(element(&node.0)?.name.borrow().local.to_string())
        })?,
    )?;
    table.set(
        "set_tag_name",
        lua.create_function(|_, (node, name): (UserDataRef<LuaNodeRef>, LuaString)| {
            element(&node.0)?.name.borrow_mut().local = LocalName::from(name.to_str()?);
            Ok(())
        })?,
    )?;
    table.set(
        "get_attribute",
        lua.create_function(|lua, (node, name): (UserDataRef<LuaNodeRef>, LuaString)| {
            if let Some(attr) = element(&node.0)?.attributes.borrow().get(name.to_str()?) {
                Ok(Some(lua.create_string(attr)?))
            } else {
                Ok(None)
            }
        })?,
    )?;
    table.set(
        "set_attribute",
        lua.create_function(
            |_, (node, name, value): (UserDataRef<LuaNodeRef>, LuaString, LuaString)| {
                element(&node.0)?
                    .attributes
                    .borrow_mut()
                    .insert(name.to_str()?, value.to_string_lossy().to_string());
                Ok(())
            },
        )?,
    )?;
    table.set(
        "delete_attribute",
        lua.create_function(|_, (node, name): (UserDataRef<LuaNodeRef>, LuaString)| {
            element(&node.0)?
                .attributes
                .borrow_mut()
                .remove(name.to_str()?);
            Ok(())
        })?,
    )?;
    table.set(
        "list_attributes",
        lua.create_function(|lua, node: UserDataRef<LuaNodeRef>| {
            let table = lua.create_table()?;
            for (attr, _) in element(&node.0)?.attributes.borrow().map.iter() {
                table.push(lua.create_string(attr.local.to_string())?)?;
            }
            Ok(table)
        })?,
    )?;
    table.set(
        "clear_attributes",
        lua.create_function(|_, node: UserDataRef<LuaNodeRef>| {
            element(&node.0)?.attributes.borrow_mut().map.clear();
            Ok(())
        })?,
    )?;
    // TODO: HTML.get_classes
    // TODO: HTML.has_class
    // TODO: HTML.add_class
    // TODO: HTML.remove_class
    // TODO: HTML.inner_html
    // TODO: HTML.inner_text
    // TODO: HTML.strip_tags

    // Element tree manipulation
    // - Implemented in lua: HTML.append_root
    // - Implemented in lua: HTML.prepend_root
    // - Implemented in lua: HTML.replace
    // - Implemented in lua: HTML.replace_element
    // - Implemented in lua: HTML.replace_content
    // - Implemented in lua: HTML.delete
    // - Implemented in lua: HTML.wrap
    // - Implemented in lua: HTML.swap
    table.set(
        "append_child",
        lua.create_function(
            |_, (parent, child): (UserDataRef<LuaNodeRef>, UserDataRef<LuaNodeRef>)| {
                parent.0.append(child.0.clone());
                Ok(())
            },
        )?,
    )?;
    table.set(
        "prepend_child",
        lua.create_function(
            |_, (parent, child): (UserDataRef<LuaNodeRef>, UserDataRef<LuaNodeRef>)| {
                parent.0.prepend(child.0.clone());
                Ok(())
            },
        )?,
    )?;
    table.set(
        "insert_before",
        lua.create_function(
            |_, (parent, child): (UserDataRef<LuaNodeRef>, UserDataRef<LuaNodeRef>)| {
                parent.0.insert_before(child.0.clone());
                Ok(())
            },
        )?,
    )?;
    table.set(
        "insert_after",
        lua.create_function(
            |_, (parent, child): (UserDataRef<LuaNodeRef>, UserDataRef<LuaNodeRef>)| {
                parent.0.insert_after(child.0.clone());
                Ok(())
            },
        )?,
    )?;
    table.set(
        "delete_element",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            elem.0.detach();
            Ok(())
        })?,
    )?;
    table.set(
        "delete_content",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            for child in elem.0.children() {
                child.detach();
            }
            Ok(())
        })?,
    )?;
    table.set(
        "unwrap",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            for child in elem.0.children().rev() {
                elem.0.insert_after(child);
            }
            Ok(())
        })?,
    )?;

    // High-level convenience functions
    // - Implemented in lua: HTML.get_heading_level
    // - Implemented in lua: HTML.get_headings_tree

    // Node tests
    table.set(
        "is_comment",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            Ok(elem.0 .0.as_comment().is_some())
        })?,
    )?;
    table.set(
        "is_doctype",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            Ok(elem.0 .0.as_doctype().is_some())
        })?,
    )?;
    table.set(
        "is_document",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            Ok(elem.0 .0.as_document().is_some())
        })?,
    )?;
    table.set(
        "is_element",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| {
            Ok(elem.0 .0.as_element().is_some())
        })?,
    )?;
    table.set(
        "is_text",
        lua.create_function(|_, elem: UserDataRef<LuaNodeRef>| Ok(elem.0 .0.as_text().is_some()))?,
    )?;

    Ok(table)
}

#[derive(Clone, Debug)]
struct LuaNodeRef(NodeRef);
impl UserData for LuaNodeRef {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "NodeRef");
    }
}
