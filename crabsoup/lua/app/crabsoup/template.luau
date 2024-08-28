--!strict
--!native

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
        data = HTML.parse_document(Sys.read_file(config.parsed.settings.default_template_file)),
        selector = table.concat(config.parsed.settings.default_content_selector, ","),
        action = utils.lookup_action(config.parsed.settings.default_content_action),
        filter = function(globals)
            return true
        end,
    }
end

local function parse_template(default_template: Template, name: string, value): Template
    local template = table.clone(default_template)
    template.name = name
    if value.file then
        template.data = HTML.parse_document(Sys.read_file(value.file))
    end
    if #value.content_selector > 0 then
        template.selector = table.concat(value.content_selector, ",")
    end
    template.filter = utils.parse_limiting_options(value)
    return template
end

function module.parse_templates(config): TemplateInfo
    local default = parse_default_template(config)

    local templates = {}
    for name, template in config.parsed.templates do
        table.insert(templates, parse_template(default, name, template))
    end
    table.sort(templates, function(a, b)
        return a.name < b.name
    end)

    return {
        default = default,
        specific = templates,
    }
end

local function resolve_template(info: TemplateInfo, globals: Globals): Template
    local matches = {}
    local matches_k = {}

    for _, template in info.specific do
        if template.filter(globals) then
            table.insert(matches, template)
            table.insert(matches_k, `'{template.name}'`)
        end
    end

    if #matches == 0 then
        return info.default
    elseif #matches == 1 then
        return matches[1]
    else
        Log.warn(`Template set is ambigious for '{globals.page_file}': {table.concat(matches_k, ", ")} all match.`)
        return matches[1]
    end
end

function module.apply_template(info: TemplateInfo, globals: Globals): ()
    local template = resolve_template(info, globals)

    local new_page = HTML.clone(template.data)
    local node = HTML.select_one(new_page, template.selector)
    if not node then
        Log.error(`Selector '{template.selector}' matches no elements in template '{template.name}'`)
        error("Selector did not match template.")
    else
        template.action(node, globals.page)
        globals.page = new_page
    end
end

return module
