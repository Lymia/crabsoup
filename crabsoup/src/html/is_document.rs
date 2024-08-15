use html5ever::{
    interface::{ElementFlags, NodeOrText, QuirksMode, TreeSink},
    tendril::{StrTendril, TendrilSink},
    Attribute, ExpandedName, LocalName, Namespace, ParseOpts, QualName,
};
use std::borrow::Cow;

struct IsDocumentTreeSink {
    handle_id: usize,
    is_document: bool,
    elements: Vec<Option<(Namespace, LocalName)>>,
}
impl Default for IsDocumentTreeSink {
    fn default() -> Self {
        IsDocumentTreeSink { handle_id: 0, is_document: false, elements: vec![] }
    }
}

impl IsDocumentTreeSink {
    fn handle(&mut self) -> usize {
        let id = self.handle_id;
        self.handle_id += 1;
        id
    }
}

impl TreeSink for IsDocumentTreeSink {
    type Handle = usize;
    type Output = bool;

    fn finish(self) -> Self::Output {
        self.is_document
    }

    fn parse_error(&mut self, _: Cow<'static, str>) {}

    fn get_document(&mut self) -> Self::Handle {
        usize::MAX
    }

    fn elem_name<'a>(&'a self, h: &'a Self::Handle) -> ExpandedName<'a> {
        let t = &self.elements[*h];
        let t = t.as_ref().unwrap();
        ExpandedName { ns: &t.0, local: &t.1 }
    }

    fn create_element(
        &mut self,
        name: QualName,
        _: Vec<Attribute>,
        _: ElementFlags,
    ) -> Self::Handle {
        self.elements.push(Some((name.ns, name.local)));
        self.handle()
    }

    fn create_comment(&mut self, _: StrTendril) -> Self::Handle {
        self.elements.push(None);
        self.handle()
    }

    fn create_pi(&mut self, _: StrTendril, _: StrTendril) -> Self::Handle {
        self.elements.push(None);
        self.handle()
    }

    fn append(&mut self, _: &Self::Handle, _: NodeOrText<Self::Handle>) {}

    fn append_based_on_parent_node(
        &mut self,
        _: &Self::Handle,
        _: &Self::Handle,
        _: NodeOrText<Self::Handle>,
    ) {
    }

    fn append_doctype_to_document(&mut self, _: StrTendril, _: StrTendril, _: StrTendril) {
        self.is_document = true;
    }

    fn get_template_contents(&mut self, _: &Self::Handle) -> Self::Handle {
        todo!()
    }

    fn same_node(&self, x: &Self::Handle, y: &Self::Handle) -> bool {
        x == y
    }

    fn set_quirks_mode(&mut self, _: QuirksMode) {}

    fn append_before_sibling(&mut self, _: &Self::Handle, _: NodeOrText<Self::Handle>) {}

    fn add_attrs_if_missing(&mut self, _: &Self::Handle, _: Vec<Attribute>) {}

    fn remove_from_parent(&mut self, _: &Self::Handle) {}

    fn reparent_children(&mut self, _: &Self::Handle, _: &Self::Handle) {}
}

pub fn is_document(source: &str) -> bool {
    html5ever::parse_document(IsDocumentTreeSink::default(), ParseOpts::default()).one(source)
}
