--!strict

local builtin_funcs, _G = ...

local function join_selectors(selectors: any?): string
    if type(selectors) == "table" then
        return table.concat(selectors, ",")
    else
        error("selector list must be a table")
    end
end

function _G.HTML.select_any_of(node, list)
    return HTML.select_one(node, join_selectors(list))
end
function _G.HTML.select_all_of(node, list)
    return HTML.select(node, join_selectors(list))
end
function _G.HTML.matches_any_of_selectors(node, list)
    return HTML.matches_selector(node, join_selectors(list))
end

_G.HTML.append_root = HTML.append_child
_G.HTML.prepend_root = HTML.prepend_child
_G. HTML.replace = HTML.replace_element
