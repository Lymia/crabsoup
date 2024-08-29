--!strict
--!native

local utils = require("crabsoup.utils")

local module = {}

type Globals = { [string]: any }
type WidgetConfig = {
    name: string,
    plugin: string,
    after: { string },
    filter: (globals: Globals) -> boolean,
    widget_config: any,
}
type WidgetsConfig = { WidgetConfig }

type Widget = {
    name: string,
    plugin: (globals: Globals, name_tag: string?) -> thread,
    filter: (globals: Globals) -> boolean,
    config: any,
    persistent_data: any,
}

local function parse_widgets(config): WidgetsConfig
    local list = {} :: WidgetsConfig
    for k, v in config.parsed.widgets do
        local widget: WidgetConfig = {
            name = k,
            plugin = v.widget,
            after = v.after,
            filter = utils.parse_limiting_options(v),
            widget_config = config.raw.widgets[k],
        }
        table.insert(list, widget)
    end
    return list
end

local function resolve_widgets(plugins, widgets: WidgetsConfig): { Widget }
    local full_list = {}
    for k, v in widgets do
        table.insert(full_list, v)
    end
    table.sort(full_list, function(a, b)
        return a.name < b.name
    end)

    local resolved = {}
    local resolved_list = {}

    while #resolved_list ~= #full_list do
        for k, v in full_list do
            if not resolved[v.name] then
                if
                    Table.for_all(function(v)
                        return not not resolved[v]
                    end, v.after)
                then
                    resolved[v.name] = true
                    local widget = {
                        name = v.name,
                        plugin = plugins:resolve(v.plugin),
                        filter = v.filter,
                        config = v.widget_config,
                        persistent_data = {},
                    }
                    table.insert(resolved_list, widget)
                end
            end
        end
    end

    return resolved_list
end

function module.load_widgets(plugins, config): { Widget }
    return resolve_widgets(plugins, parse_widgets(config))
end

local function run_widget(widget: Widget, globals: Globals)
    if Log.trace_enabled then
        Log.trace(`Running widget '{widget.name}' for page '{globals.page_file}'`)
    end

    local pass_globals = table.clone(globals)
    pass_globals.config = Table.deep_clone(widget.config) -- some plugins modify this, so unfreeze it
    pass_globals.persistent_data = widget.persistent_data
    pass_globals.widget_name = widget.name

    local values = {}
    if widget.filter(pass_globals) then
        local thread = widget.plugin(pass_globals, globals.relative_page_file)
        while true do
            local success, r = coroutine.resume(thread, unpack(values))
            if success then
                local status = coroutine.status(thread)
                if status == "suspended" then
                    values = { coroutine.yield(r) }
                    if values[1] and typeof(values[1]) == "PluginInstruction" and values[1]:is_exit() then
                        break
                    end
                elseif status == "dead" then
                    globals.page = pass_globals.page
                    if typeof(globals.page) ~= "NodeRef" then
                        error(`'page' must be a NodeRef, not a {typeof(globals.page)}`)
                    end
                    break
                else
                    error(`Internal error: Invalid widget coroutine status: {status}`)
                end
            else
                error(`Could not process widget '{widget.name}' for page '{globals.page_file}':\n{r}`)
            end
        end
    end
end

function module.run_widgets(widgets: { Widget }, globals: Globals)
    for _, v in widgets do
        run_widget(v, globals)
    end
end

return module
