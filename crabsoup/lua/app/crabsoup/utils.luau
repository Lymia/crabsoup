--!strict

local module = {}

local action_map: { [string]: (NodeRef, NodeRef) -> () } = {
    prepend = HTML.prepend,
    prepend_child = HTML.prepend,
    append = HTML.append,
    append_child = HTML.append_child,
    insert_before = HTML.insert_before,
    insert_after = HTML.insert_after,
    replace_content = HTML.replace_content,
    replace_element = HTML.replace_element,
}
function module.lookup_action(action_name: string): (NodeRef, NodeRef) -> ()
    local result = action_map[action_name]
    if not result then
        error(`Unknown content action: {action_name}`)
    end
    return result
end

function module.parse_limiting_options(table)
    return function()
        return true
    end
end

return module
