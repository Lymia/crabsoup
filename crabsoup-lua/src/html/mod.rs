use crate::html::{
    detached_tree_sink::DetachedTreeSink, is_document_tree_sink::IsDocumentTreeSink,
};
use anyhow::Result;
use ego_tree::NodeId;
use html5ever::{
    local_name, namespace_url, ns, serialize::TraversalScope, tendril::TendrilSink, ParseOpts,
    QualName,
};
use scraper::Html;

mod detached_tree_sink;
mod is_document_tree_sink;
mod serialize;

/// Code copied from `scraper` crate.
mod tendril_util {
    use html5ever::tendril;

    /// Atomic equivalent to the default `StrTendril` type.
    pub type StrTendril = tendril::Tendril<tendril::fmt::UTF8, tendril::Atomic>;

    /// Convert a standard tendril into an atomic one.
    pub fn make(s: tendril::StrTendril) -> StrTendril {
        s.into_send().into()
    }
}

pub use detached_tree_sink::TreeSinkResult;

fn is_document(source: &str) -> bool {
    html5ever::parse_document(IsDocumentTreeSink::default(), ParseOpts::default()).one(source)
}

pub fn parse_into(html: &mut Html, source: &str) -> TreeSinkResult {
    if is_document(source) {
        html5ever::parse_document(DetachedTreeSink::new(html, false), ParseOpts::default())
            .one(source)
    } else {
        html5ever::parse_fragment(
            DetachedTreeSink::new(html, true),
            ParseOpts::default(),
            QualName::new(None, ns!(html), local_name!("body")),
            Vec::new(),
        )
        .one(source)
    }
}

pub fn to_html(html: &Html, root: NodeId) -> Result<String> {
    serialize::serialize_from_node(html, root, TraversalScope::IncludeNode)
}

pub fn to_inner_html(html: &Html, root: NodeId) -> Result<String> {
    serialize::serialize_from_node(html, root, TraversalScope::ChildrenOnly(None))
}

pub fn to_inner_text(html: &Html, root: NodeId) -> Result<String> {
    serialize::to_inner_text(html, root)
}
