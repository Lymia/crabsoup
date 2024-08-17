--!strict

local utils = require("crabsoup.utils")

type TocContext = {
    page: NodeRef,
    relative_page_file: string,
    list_tag: string,
}
local function build_ctx(globals): TocContext
    return {
        page = globals.page,
        relative_page_file = globals.relative_page_file,
        list_tag = if globals.numbered_list then "ol" else "ul",
    }
end

local function tag_with_ids(ctx: TocContext, node)
    local id = HTML.get_attribute(node.heading, "id")
    if id then
        if #HTML.select(ctx.page, `[id='{String.escape_css(id)}']`) ~= 1 then
            Log.warn(`Duplicated id '#{id}' found in page '{ctx.relative_page_file}'.`)
        end
        node.id = id
    else
        local orig_slug = String.slugify(HTML.inner_text(node.heading))
        local slug = orig_slug

        local i = 2
        while HTML.select_one(ctx.page, `[id='{String.escape_css(slug)}']`) do
            if i == 2 then
                Log.warn(`Slug id '#{slug}' already exists in '{ctx.relative_page_file}'. Using alternative.`)
            end
            slug = `{orig_slug}-{i}`
            i += 1
        end

        -- Assign the ID
        HTML.set_attribute(node.heading, "id", slug)
        node.id = slug
    end

    for _, v in node.children do
        tag_with_ids(ctx, v)
    end
end

local function build_toc(ctx: TocContext, node, level: number): NodeRef
    local tag = HTML.create_element(ctx.list_tag)
    HTML.add_class(tag, "toc") -- TODO: arguments

    for _, v in node.children do
        local li = HTML.create_element("li")
        local link = HTML.create_element("a", HTML.inner_text(v.heading))
        HTML.set_attribute(link, "href", `#{v.id}`)
        HTML.append(li, link)

        if #v.children > 0 then
            HTML.append(li, build_toc(ctx, v, level + 1))
        end

        HTML.append(tag, li)
    end

    return tag
end

local function toc(globals)
    local ctx = build_ctx(globals)
    local headings = HTML.get_headings_tree(globals.page) :: any

    tag_with_ids(ctx, headings)
    local toc_node = build_toc(ctx, headings, 1)

    local selector = utils.parse_toml_selector(globals.config.selector)
    local node = HTML.select_one(globals.page, selector)
    if node then
        HTML.append(node, toc_node)
    end
end

return { toc = toc }
