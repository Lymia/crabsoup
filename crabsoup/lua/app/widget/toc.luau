--!strict
--!native

local utils = require("crabsoup.utils")

-- TODO: Support for customizing slugs.

type TocContext = {
    page: NodeRef,
    relative_page_file: string,
    list_tag: string,
    min_level: number,
    max_level: number,
    max_heading_link_level: number,

    toc_list_class: string?,
    toc_class_levels: boolean,

    heading_links: boolean,
    heading_link_text: string?,
    heading_link_class: string?,
    heading_links_append: boolean,

    ignore_heading_selectors: string,
    ignore_heading_link_selectors: string,
}
type TocIndex = {
    id: string?,
    heading: NodeRef?,
    children: { TocIndex },
}

local function build_ctx(globals): TocContext
    local config = globals.config
    if config.valid_html ~= nil and not config.valid_html then
        Log.warn(`Crabsoup's 'toc' widget does not support 'valid_html = false'.`)
    end
    return {
        page = globals.page,
        relative_page_file = globals.relative_page_file,
        list_tag = if config.numbered_list then "ol" else "ul",

        min_level = config.min_level or 2,
        max_level = config.max_level or 6,
        max_heading_link_level = config.max_heading_link_level or config.max_level or 6,

        toc_list_class = config.toc_list_class,
        toc_class_levels = not not config.toc_class_levels,

        heading_links = not not config.heading_links,
        heading_link_text = config.heading_link_text,
        heading_link_class = config.heading_link_class,
        heading_links_append = not not config.heading_links_append,

        ignore_heading_selectors = utils.parse_toml_selector(globals.ignore_heading_selectors),
        ignore_heading_link_selectors = utils.parse_toml_selector(
            globals.ignore_heading_link_selectors or globals.ignore_heading_selectors
        ),
    }
end

local function tag_with_ids(page: NodeRef, ctx: TocContext, node): TocIndex
    if node.heading then
        local id = HTML.get_attribute(node.heading, "id")
        if id then
            if #HTML.select(ctx.page, `[id='{String.escape_css(id)}']`) ~= 1 then
                Log.error(`Duplicated id '#{id}' found in page '{ctx.relative_page_file}'.`)
            end
            node.id = id
        else
            -- Assign the ID
            local slug = utils.find_unique_id(page, String.slugify(HTML.inner_text(node.heading)))
            HTML.set_attribute(node.heading, "id", slug)
            node.id = slug
        end
    end

    for _, v in node.children do
        tag_with_ids(page, ctx, v)
    end

    return node
end

local function build_toc(ctx: TocContext, node: TocIndex, level: number): NodeRef
    local tag_level = if node.heading then HTML.get_heading_level(node.heading) else 0
    local omitted = false
    local tag
    if tag_level + 1 < ctx.min_level then
        tag = HTML.create_document() -- acts as a container for the children
        omitted = true
    else
        tag = HTML.create_element(ctx.list_tag)
        if ctx.toc_list_class then
            local class = ctx.toc_list_class
            if ctx.toc_class_levels then
                class = `{class}-{level}`
            end
            HTML.add_class(tag, class)
        end
    end

    for _, v in node.children do
        if v.heading then
            if
                HTML.get_heading_level(v.heading) <= ctx.max_level
                and not HTML.matches(v.heading, ctx.ignore_heading_selectors)
            then
                if omitted then
                    if #v.children > 0 then
                        HTML.append(tag, build_toc(ctx, v, level))
                    end
                else
                    local li = HTML.create_element("li")
                    local link = HTML.create_element("a", HTML.inner_text(v.heading))
                    HTML.set_attribute(link, "href", `#{v.id}`)
                    HTML.append(li, link)

                    if #v.children > 0 then
                        HTML.append(li, build_toc(ctx, v, level + 1))
                    end

                    HTML.append(tag, li)
                end
            end
        end
    end

    return tag
end

local function build_section_tags(ctx: TocContext, node: TocIndex, is_root: boolean)
    if not is_root and node.id and node.heading then
        local level = HTML.get_heading_level(node.heading)
        if
            level >= ctx.min_level
            and level <= ctx.max_heading_link_level
            and not HTML.matches(node.heading, ctx.ignore_heading_link_selectors)
        then
            local heading_link = HTML.create_element("a", ctx.heading_link_text)
            if ctx.heading_link_class then
                HTML.add_class(heading_link, ctx.heading_link_class)
            end
            HTML.set_attribute(heading_link, "href", `#{node.id}`)

            if ctx.heading_links_append then
                HTML.append(node.heading, heading_link)
            else
                HTML.prepend(node.heading, heading_link)
            end
        end
    end

    for _, v in node.children do
        build_section_tags(ctx, v, false)
    end
end

local function toc(globals)
    local ctx = build_ctx(globals)

    local tree: TocIndex = {
        children = HTML.get_headings_tree(globals.page) :: any,
    }
    if #tree.children > 0 then
        local nodes = tag_with_ids(globals.page, ctx, tree :: any)
        local toc_node = build_toc(ctx, nodes, 1)
        if ctx.heading_links then
            build_section_tags(ctx, nodes, true)
        end

        local selector = utils.parse_toml_selector(globals.config.selector)
        local node = HTML.select_one(globals.page, selector)
        if node then
            HTML.append(node, toc_node)
        end
    end
end

return { toc = toc }
