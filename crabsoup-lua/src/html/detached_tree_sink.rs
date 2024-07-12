use crate::html::tendril_util;
use ego_tree::NodeId;
use html5ever::{
    interface::{ElementFlags, NodeOrText, QuirksMode, TreeSink},
    tendril::StrTendril,
    Attribute, ExpandedName, QualName,
};
use scraper::{node::Doctype, Html, Node};
use std::borrow::Cow;

pub struct DetachedTreeSink<'a> {
    parent: &'a mut Html,
    new_root: NodeId,
    errors: Vec<Cow<'static, str>>,
    quirks_mode: QuirksMode,
}
impl<'a> DetachedTreeSink<'a> {
    pub fn new(parent: &'a mut Html, is_fragment: bool) -> Self {
        let new_root = parent
            .tree
            .orphan(if is_fragment { Node::Fragment } else { Node::Document })
            .id();
        DetachedTreeSink { parent, new_root, errors: vec![], quirks_mode: QuirksMode::NoQuirks }
    }
}

#[derive(Debug, Clone)]
pub struct TreeSinkResult {
    pub root_node: NodeId,
    pub errors: Vec<Cow<'static, str>>,
    pub quirks_mode: QuirksMode,
}

impl<'a> TreeSink for DetachedTreeSink<'a> {
    type Handle = NodeId;

    type Output = TreeSinkResult;

    fn finish(self) -> Self::Output {
        TreeSinkResult {
            root_node: self.new_root,
            errors: self.errors,
            quirks_mode: self.quirks_mode,
        }
    }

    fn parse_error(&mut self, msg: Cow<'static, str>) {
        self.errors.push(msg);
    }

    fn get_document(&mut self) -> Self::Handle {
        self.new_root
    }

    fn elem_name<'b>(&'b self, target: &'b Self::Handle) -> ExpandedName<'b> {
        self.parent.elem_name(target)
    }

    fn create_element(
        &mut self,
        name: QualName,
        attrs: Vec<Attribute>,
        flags: ElementFlags,
    ) -> Self::Handle {
        self.parent.create_element(name, attrs, flags)
    }

    fn create_comment(&mut self, text: StrTendril) -> Self::Handle {
        self.parent.create_comment(text)
    }

    fn create_pi(&mut self, target: StrTendril, data: StrTendril) -> Self::Handle {
        self.parent.create_pi(target, data)
    }

    fn append(&mut self, parent: &Self::Handle, child: NodeOrText<Self::Handle>) {
        self.parent.append(parent, child)
    }

    fn append_based_on_parent_node(
        &mut self,
        element: &Self::Handle,
        prev_element: &Self::Handle,
        child: NodeOrText<Self::Handle>,
    ) {
        self.parent
            .append_based_on_parent_node(element, prev_element, child)
    }

    fn append_doctype_to_document(
        &mut self,
        name: StrTendril,
        public_id: StrTendril,
        system_id: StrTendril,
    ) {
        let name = tendril_util::make(name);
        let public_id = tendril_util::make(public_id);
        let system_id = tendril_util::make(system_id);
        let doctype = Doctype { name, public_id, system_id };
        self.parent
            .tree
            .get_mut(self.new_root)
            .unwrap()
            .append(Node::Doctype(doctype));
    }

    fn get_template_contents(&mut self, target: &Self::Handle) -> Self::Handle {
        self.parent.get_template_contents(target)
    }

    fn same_node(&self, x: &Self::Handle, y: &Self::Handle) -> bool {
        self.parent.same_node(x, y)
    }

    fn set_quirks_mode(&mut self, mode: QuirksMode) {
        self.quirks_mode = mode;
    }

    fn append_before_sibling(
        &mut self,
        sibling: &Self::Handle,
        new_node: NodeOrText<Self::Handle>,
    ) {
        self.parent.append_before_sibling(sibling, new_node)
    }

    fn add_attrs_if_missing(&mut self, target: &Self::Handle, attrs: Vec<Attribute>) {
        self.parent.add_attrs_if_missing(target, attrs)
    }

    fn remove_from_parent(&mut self, target: &Self::Handle) {
        self.parent.remove_from_parent(target)
    }

    fn reparent_children(&mut self, node: &Self::Handle, new_parent: &Self::Handle) {
        self.parent.reparent_children(node, new_parent)
    }
}
