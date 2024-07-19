--!strict

local builtin_funcs, _G = ...

-- Function definitions for `HTML` module
function builtin_funcs.create_html_library(context)
    local HTML = {}

    return table.freeze(HTML)
end
