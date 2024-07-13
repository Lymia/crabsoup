use anyhow::Result;
use crabsoup_lua::{html::parse_into, lua::CrabsoupLuaContext};
use html5ever::{tendril::TendrilSink, ParseOpts};
use scraper::Html;

const HTML_TEST: &str = "
<!doctype html>
<html lang=en>
<head>
<meta charset=utf-8>
<title>blah</title>
</head>
<body>
<p>I'm the content</p>
</body>
</html>
";

const HTML_TEST_TWO: &str = "
<!doctype html>
<html lang=en>
<head>
<meta charset=utf-8>
<title>blah</title>
</head>
<body>
<p>I'm the content</p>
<p>And this is more content!</p>
</body>
</html>
";

fn main() -> Result<()> {
    let mut document = Html::parse_document(HTML_TEST);
    let result = parse_into(&mut document, HTML_TEST_TWO);
    let result_fragment = parse_into(&mut document, "<p>testing</p>");

    println!("{document:?}");
    println!("{result:?}");
    println!("{result_fragment:?}");
    println!("{:?}", document.html());
    println!("{:?}", crabsoup_lua::html::to_html(&document, result.root_node)?);
    println!("{:?}", crabsoup_lua::html::to_html(&document, result_fragment.root_node)?);
    println!("{:?}", crabsoup_lua::html::to_inner_text(&document, result.root_node)?);

    CrabsoupLuaContext::new()?.repl()?;

    Ok(())
}
