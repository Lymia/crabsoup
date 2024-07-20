--!strict

local builtin_funcs, _G = ...

local HTML = _G.HTML

local append_child = HTML.append_child
local create_text = HTML.create_text
local delete_element = HTML.delete_element
local delete_content = HTML.delete_content
local get_attribute = HTML.get_attribute
local insert_after = HTML.insert_after
local set_attribute = HTML.set_attribute

function _G.HTML.append_attribute(node, attr, value)
    set_attribute(node, get_attribute(node, attr) .. value)
end

function _G.HTML.replace_element(orig, new)
    insert_after(orig, new)
    delete_element(orig)
end
function _G.HTML.replace_content(parent, child)
    delete_content(parent)
    append_child(parent, child)
end
function _G.HTML.wrap(node, elem)
    insert_after(node, elem)
    append_child(elem, node)
end
function _G.HTML.swap(node_a, node_b)
    local temp_node = create_text("")
    insert_after(node_a, temp_node)
    insert_after(node_b, node_a)
    insert_after(temp_node, node_b)
    delete_element(temp_node)
end

HTML.append = HTML.append_child
HTML.delete = HTML.delete_element
HTML.prepend = HTML.prepend_child
