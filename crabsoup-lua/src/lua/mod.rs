use crate::wyhash::WyHashMap;
use ego_tree::NodeId;
use mlua::{MetaMethod, UserData, UserDataFields, UserDataMethods};
use scraper::{Html, Node};
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
}
impl HtmlContext {
    pub fn new() -> HtmlContext {
        HtmlContext { ctx_id: ContextId::new(), dom: Html::new_document() }
    }

    fn new_node(&mut self, node: Node) -> HtmlNode {
        let id = self.dom.tree.orphan(node).id();
        self.node(id)
    }

    fn node(&self, id: NodeId) -> HtmlNode {
        HtmlNode { ctx_id: self.ctx_id, node_id: id }
    }
}
impl UserData for HtmlContext {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "HtmlContext");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method_mut("create_document", |_, this, ()| Ok(this.new_node(Node::Document)));
    }
}

#[derive(Copy, Clone, Eq, PartialEq)]
pub struct HtmlNode {
    ctx_id: ContextId,
    node_id: NodeId,
}
impl UserData for HtmlNode {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_meta_field("__type", "HtmlNode");
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(format!("HtmlNode: {:?}@{:?}", this.ctx_id, this.node_id))
        })
    }
}
