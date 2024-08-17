--!strict

local function tag_with_ids(globals, node)
    local id = HTML.get_attribute(node.heading, "id")
    if id then
        if #HTML.select(globals.page, `[id='{String.escape_css(id)}']`) ~= 1 then
            Log.warn(`Duplicated id '#{id}' found in page '{globals.relative_page_file}'.`)
        end
        node.id = id
    else
        local orig_slug = String.slugify(HTML.inner_text(node.heading))
        local slug = orig_slug

        local i = 2
        while HTML.select_one(globals.page, `[id='{String.escape_css(slug)}']`) do
            if i == 2 then
                Log.warn(`Slug id '#{slug}' already exists in '{globals.relative_page_file}'. Using alternative.`)
            end
            slug = `{orig_slug}-{i}`
            i += 1
        end

        -- Assign the ID
        HTML.set_attribute(node.heading, "id", slug)
        node.id = slug
    end

    for _, v in node.children do
        tag_with_ids(globals, v)
    end
end

local function toc(globals)
    local headings = HTML.get_headings_tree(globals.page) :: any
    tag_with_ids(globals, headings)
end

return { toc = toc }
