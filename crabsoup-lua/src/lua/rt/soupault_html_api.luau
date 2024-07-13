--!strict

local builtin_funcs = ...

-- Stored stdlib functions
local table_freeze = table.freeze

-- Function definitions for `HTML` module
function builtin_funcs.create_html_library(context)
    local HTML = {}

    return table_freeze(HTML)
end
