--!strict

local utils = require("crabsoup.utils")

local module = {}

type Globals = { [string]: any }
type Template = {
    name: string,
    data: NodeRef,
    selector: string,
    action: (NodeRef, NodeRef) -> (),
    filter: (globals: Globals) -> boolean,
}
type TemplateInfo = {
    default: Template,
    specific: { Template },
}

local function parse_default_template(config): Template
    return {
        name = ".default",
        data = HTML.parse(Sys.read_file(config.parsed.settings.default_template_file)),
        selector = config.parsed.settings.default_content_selector,
        action = utils.lookup_action(config.parsed.settings.default_content_action),
        filter = function(globals)
            return true
        end,
    }
end

function module.parse_templates(config): TemplateInfo
    local default = parse_default_template(config)
    return error("!")
end

return module
