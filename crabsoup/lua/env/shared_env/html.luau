--!strict
--!native

local _, _G = ...

function _G.HTML.append_attribute(node, attr, value)
    HTML.set_attribute(node, attr, HTML.get_attribute(node, attr) .. value)
end

function _G.HTML.replace_element(orig, new)
    HTML.insert_after(orig, new)
    HTML.delete_element(orig)
end
function _G.HTML.replace_content(parent, child)
    HTML.delete_content(parent)
    HTML.append_child(parent, child)
end
function _G.HTML.wrap(node, elem)
    assert(not HTML.is_document(elem), "`wrap` cannot be used on document nodes", 2)
    HTML.insert_after(node, elem)
    HTML.append_child(elem, node)
end
function _G.HTML.swap(node_a, node_b)
    assert(not HTML.is_document(node_a) and not HTML.is_document(node_b), "`swap` cannot be used on document nodes")

    local temp_node = HTML.create_text("")
    HTML.insert_after(node_a, temp_node)
    HTML.insert_after(node_b, node_a)
    HTML.insert_after(temp_node, node_b)
    HTML.delete_element(temp_node)
end

_G.HTML.append = HTML.append_child
_G.HTML.delete = HTML.delete_element
_G.HTML.prepend = HTML.prepend_child

-- Advanced functions
local function get_heading_level(element)
    if typeof(element) == "NodeRef" and HTML.is_element(element) then
        local tag = HTML.get_tag_name(element)
        local match = string.match(tag, "h([0-9]+)")
        if match then
            return tonumber(match)
        else
            return 0
        end
    else
        return 0
    end
end
_G.HTML.get_heading_level = get_heading_level

function _G.HTML.get_headings_tree(element)
    local all_headings = HTML.select(element, "h1,h2,h3,h4,h5,h6")

    local stack = {}

    type Recursion = {
        root: boolean?,
        heading: NodeRef,
        children: { Recursion },
    }
    local current: {
        base_level: number,
        obj: Recursion,
    } = {
        base_level = 0,
        obj = {
            root = true,
            heading = HTML.parse("a"),
            children = {},
        },
    }

    -- process all headings
    for _, heading in all_headings do
        local level = get_heading_level(heading)

        -- pop to the appropriate level
        while level <= current.base_level do
            if #stack == 0 then
                return error("stack underflow while processing heading tree")
            end

            local top = table.pop(stack)
            table.insert(top.obj.children, current.obj)
            current = top
        end

        -- push a new frame
        table.insert(stack, current)
        current = {
            base_level = level,
            obj = {
                heading = heading,
                children = {},
            },
        }
    end

    -- pop any remaining stack items
    while #stack > 0 do
        local top = table.pop(stack)
        table.insert(top.obj.children, current.obj)
        current = top
    end
    assert(current.obj.root)

    -- Fix multiple frames
    return current.obj.children
end

-- TODO: Implement `HTML.get_headings_tree`
