--!strict

local builtin_funcs, _G = ...

local HTML = table.clone(_G.HTML)
_G.HTML = HTML

local matches_selector = HTML.matches_selector
local select = HTML.select
local select_one = HTML.select_one

local function join_selectors(selectors: any?): string
    if type(selectors) == "table" then
        return table.concat(selectors, ",")
    else
        error("selector list must be a table")
    end
end

function HTML.select_any_of(node, list)
    return select_one(node, join_selectors(list))
end
function HTML.select_all_of(node, list)
    return select(node, join_selectors(list))
end
function HTML.matches_any_of_selectors(node, list)
    return matches_selector(node, join_selectors(list))
end

HTML.append_root = HTML.append_child
HTML.prepend_root = HTML.prepend_child
HTML.replace = HTML.replace_element
