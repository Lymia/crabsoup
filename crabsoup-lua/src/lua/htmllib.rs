use crate::{
    html::{clone_node, parse_into, to_html, to_inner_html},
    wyhash::WyHashMap,
};
use ego_tree::NodeId;
use html5ever::{namespace_url, ns, LocalName, QualName};
use mlua::{
    prelude::LuaString, Error, MetaMethod, Result, UserData, UserDataFields, UserDataMethods,
    UserDataRef,
};
use scraper::{
    node::{Element, Text},
    ElementRef, Html, Node, Selector, StrTendril,
};
use std::sync::atomic::{AtomicUsize, Ordering};

#[derive(Copy, Clone, Eq, PartialEq, Ord, PartialOrd, Debug, Hash)]
pub struct ContextId(usize);
impl ContextId {
    fn new() -> Self {
        static CURRENT_ID: AtomicUsize = AtomicUsize::new(0);
        loop {
            let cur = CURRENT_ID.load(Ordering::Relaxed);
            assert_ne!(cur, usize::MAX);
            if CURRENT_ID
                .compare_exchange(cur, cur + 1, Ordering::Relaxed, Ordering::Relaxed)
                .is_ok()
            {
                return ContextId(cur);
            }
        }
    }
}

pub struct HtmlContext {
    ctx_id: ContextId,
    dom: Html,
    node_ty: WyHashMap<NodeId, NodeType>,
}
impl HtmlContext {
    pub fn new() -> HtmlContext {
        HtmlContext {
            ctx_id: ContextId::new(),
            dom: Html::new_document(),
            node_ty: Default::default(),
        }
    }

    fn root_element(&self, node: &HtmlNodeRef) -> Result<ElementRef> {
        self.check_node(node)?;

        let raw_root = self.dom.tree.get(node.node_id).unwrap();
        let elem = match node.kind {
            NodeType::Element | NodeType::Text | NodeType::Fragment => raw_root,
            NodeType::Document => {
                match raw_root
                    .children()
                    .filter(|x| x.value().is_element())
                    .next()
                {
                    None => return Err(Error::runtime("No root element found?")),
                    Some(root) => root,
                }
            }
            _ => todo!(),
        };
        match ElementRef::wrap(elem) {
            None => Err(Error::runtime("Node is not an element.")),
            Some(x) => Ok(x),
        }
    }

    fn check_node(&self, node: &HtmlNodeRef) -> Result<()> {
        if node.ctx_id != self.ctx_id {
            Err(mlua::Error::runtime("HTML nodes cannot be shared between contexts."))
        } else {
            Ok(())
        }
    }

    fn new_node(&mut self, node: Node) -> HtmlNode {
        let ty = match &node {
            Node::Document => NodeType::Document,
            Node::Fragment => NodeType::Fragment,
            _ => NodeType::Element,
        };
        let id = self.dom.tree.orphan(node).id();
        if ty != NodeType::Element {
            self.node_ty.insert(id, ty);
        }
        self.node(id)
    }

    fn clone_node(&mut self, node: NodeId) -> Result<HtmlNode> {
        let new_node = clone_node(&mut self.dom, node).map_err(Error::runtime)?;
        if let Some(ty) = self.node_ty.get(&node) {
            self.node_ty.insert(new_node, *ty);
        }
        Ok(self.node(new_node))
    }

    fn node(&self, id: NodeId) -> HtmlNode {
        HtmlNode {
            ctx_id: self.ctx_id,
            node_id: id,
            kind: self.node_ty.get(&id).cloned().unwrap_or(NodeType::Element),
        }
    }
    fn node_opt(&self, id: Option<NodeId>) -> Option<HtmlNode> {
        id.map(|x| self.node(x))
            .filter(|x| x.kind != NodeType::Fragment)
    }
}
impl UserData for HtmlContext {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "HtmlContext");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method_mut("parse", |_, this, source: LuaString| {
            let result = parse_into(&mut this.dom, source.to_str()?);
            let kind = if result.is_fragment {
                NodeType::Fragment
            } else {
                NodeType::Document
            };
            this.node_ty.insert(result.root_node, kind);
            Ok(this.node(result.root_node))
        });

        methods.add_method("to_html", |_, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            if node.kind == NodeType::Fragment {
                Ok(to_inner_html(&this.dom, node.node_id).map_err(Error::runtime)?)
            } else {
                Ok(to_html(&this.dom, node.node_id).map_err(Error::runtime)?)
            }
        });
        methods.add_method("to_inner_html", |_, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            if node.kind != NodeType::Element {
                Err(mlua::Error::runtime("Can only take inner HTML of a leaf element."))
            } else {
                Ok(to_inner_html(&this.dom, node.node_id).map_err(Error::runtime)?)
            }
        });

        methods.add_method_mut("create_document", |_, this, ()| {
            let node = this.new_node(Node::Document);
            Ok(node)
        });
        methods.add_method_mut("create_element", |_, this, name: LuaString| {
            let node = this.new_node(Node::Element(Element::new(
                QualName::new(None, ns!(html), LocalName::from(name.to_str()?)),
                Vec::new(),
            )));
            Ok(node)
        });
        methods.add_method_mut("create_text", |_, this, name: LuaString| {
            let node = this.new_node(Node::Text(Text { text: StrTendril::from(name.to_str()?) }));
            Ok(node)
        });

        methods.add_method_mut("clone_node", |_, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            Ok(this.clone_node(node.node_id).map_err(Error::runtime)?)
        });

        methods.add_method("select", |lua, this, (node, name): (HtmlNodeRef, LuaString)| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            let table = lua.create_table()?;
            for node in elem.select(&Selector::parse(name.to_str()?).map_err(Error::runtime)?) {
                table.push(this.node(node.id()))?;
            }
            Ok(table)
        });
        methods.add_method("match_selector", |_, this, (node, name): (HtmlNodeRef, LuaString)| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            let selector = Selector::parse(name.to_str()?).map_err(Error::runtime)?;
            Ok(selector.matches_with_scope(&elem, None))
        });

        methods.add_method("parent", |_, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            Ok(this.node_opt(elem.parent().map(|x| x.id())))
        });
        methods.add_method("children", |lua, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            let table = lua.create_table()?;
            for node in elem.children() {
                table.push(this.node(node.id()))?;
            }
            Ok(table)
        });
        methods.add_method("child_count", |_, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            Ok(elem.children().count())
        });

        methods.add_method("get_tag_name", |lua, this, node: HtmlNodeRef| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            Ok(lua.create_string(elem.value().name.local.as_bytes())?)
        });
        methods.add_method_mut(
            "set_tag_name",
            |_, this, (node, name): (HtmlNodeRef, LuaString)| {
                this.check_node(&node)?;
                let elem_id = this.root_element(&node)?.id();
                if let Node::Element(elem) = this.dom.tree.get_mut(elem_id).unwrap().value() {
                    elem.name.local = name.to_str()?.into();
                    Ok(())
                } else {
                    unreachable!()
                }
            },
        );
        methods.add_method("get_attribute", |lua, this, (node, name): (HtmlNodeRef, LuaString)| {
            this.check_node(&node)?;
            let elem = this.root_element(&node)?;
            if let Some(value) = elem.value().attr(name.to_str()?) {
                Ok(Some(lua.create_string(value)?))
            } else {
                Ok(None)
            }
        });
    }
}

#[derive(Copy, Clone, Eq, PartialEq, Debug)]
enum NodeType {
    Element,
    Text,
    Doctype,
    ProcessingInstruction,
    Comment,
    Document,
    Fragment,
}

#[derive(Copy, Clone, Eq, PartialEq, Debug)]
pub struct HtmlNode {
    ctx_id: ContextId,
    node_id: NodeId,
    kind: NodeType,
}
impl UserData for HtmlNode {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "HtmlNode");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(format!("HtmlNode({:?}): {:?}@{:?}", this.kind, this.ctx_id, this.node_id))
        });

        methods.add_method("is_element", |_, this, ()| Ok(this.kind == NodeType::Element));
        methods.add_method("is_text", |_, this, ()| Ok(this.kind == NodeType::Text));
        methods.add_method("is_doctype", |_, this, ()| Ok(this.kind == NodeType::Document));
        methods.add_method("is_pi", |_, this, ()| Ok(this.kind == NodeType::ProcessingInstruction));
        methods.add_method("is_comment", |_, this, ()| Ok(this.kind == NodeType::Comment));
        methods.add_method("is_document", |_, this, ()| Ok(this.kind == NodeType::Document));
        methods.add_method("is_fragment", |_, this, ()| Ok(this.kind == NodeType::Fragment));

        methods.add_method("is_same", |_, this, other: HtmlNodeRef| Ok(this == &*other));
    }
}

type HtmlNodeRef<'lua> = UserDataRef<'lua, HtmlNode>;
