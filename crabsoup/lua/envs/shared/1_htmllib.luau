--!strict

local builtin_funcs, _G = ...

function _G.HTML.append_attribute(node, attr, value)
    HTML.set_attribute(node, HTML.get_attribute(node, attr) .. value)
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
    HTML.insert_after(node, elem)
    HTML.append_child(elem, node)
end
function _G.HTML.swap(node_a, node_b)
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
function _G.HTML.get_heading_level(element)
    print(typeof(element), HTML.is_element(element), element)
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

-- TODO: Implement `HTML.get_headings_tree`