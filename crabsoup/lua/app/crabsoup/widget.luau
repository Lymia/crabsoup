--!strict

local module = {}

type Globals = { [string]: any }
type WidgetConfig = {
    plugin_name: string,
    after: { string },
    selection_functions: { (globals: Globals) -> boolean },
    widget_config: any,
}
type WidgetsConfig = { [string]: WidgetConfig }

type Widget = {
    name: string,
    plugin: (globals: Globals) -> thread,
    filter: (globals: Globals) -> boolean,
    config: any, -- MUST BE FROZEN!!
    persistent_data: any,
}

--[[
    "page",
    "page_file",
    "target_dir",
    "target_file",
    "nav_path",
    "page_url",
    "config",
    "soupault_config",
    "site_index",
    "index_entry",
    "site_dir",
    "build_dir",
    "persistent_data",
    "global_data",
    "soupault_pass",
]]

local function load_widgets(plugins, config): WidgetsConfig
    local list = {} :: WidgetsConfig
    for k, v in config.parsed.widgets do
        local widget: WidgetConfig = {
            plugin_name = k,
            after = v.after,
            selection_functions = {},
            widget_config = config.raw.widgets[k],
        }
        list[k] = widget
    end
    return list
end

local function run_widget(widget: Widget, globals: Globals)
    local pass_globals = table.clone(globals)
    pass_globals.config = widget.config
    pass_globals.persistent_data = widget.persistent_data

    if widget.filter(pass_globals) then
        local thread = widget.plugin(pass_globals)
        while true do
            local success, r = coroutine.resume(thread)
            if success then
                local status = coroutine.status(thread)
                if status == "suspended" then
                    coroutine.yield(r)
                elseif status == "dead" then
                    globals.page = pass_globals.page
                    break
                else
                    error(`Internal error: Invalid widget coroutine status: {status}`)
                end
            else
                error(`Could not process widget '{widget.name}' for page '{globals.page_file}': {r}`)
            end
        end
    end
end

local function run_widgets(widgets: { Widget }, globals: Globals)
    for _, v in widgets do
        run_widget(v, globals)
    end
end

return module
