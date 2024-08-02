local module = {}

local ty_boolean = newproxy()
local ty_string = newproxy()
local ty_string_list = newproxy()

local schema = {
    settings = {
        soupault_version = ty_string,
        strict = ty_boolean,
        site_dir = ty_string,
        build_dir = ty_string,
        page_file_extensions = ty_string_list,
        clean_urls = ty_boolean,
        keep_extensions = ty_string_list,
        default_extension = ty_string,
        ignore_extensions = ty_string_list,
        generator_mode = ty_boolean,
        complete_page_selector = ty_string,
        default_template_file = ty_string,
        default_content_selector = ty_string,
        default_content_action = ty_string,
        keep_doctype = ty_boolean,
        doctype = ty_string,
        pretty_print_html = ty_boolean,
        plugin_discovery = ty_boolean,
        plugin_dirs = ty_string_list,
        page_character_encoding = ty_string,

        -- Deprecated
        verbose = ty_boolean,
        debug = ty_boolean,
        caching = ty_boolean,
        cache_dir = ty_string,
    },
}

local function schema_error()
    error("Type error in configuration!", 2)
end

local function check_schema(config_name, schema, table)
    if type(table) ~= "table" then
        Log.error("Main config root is not a table??")
        error("could not parse config")
    end

    for k, v in table do
        if type(k) ~= "string" then
            Log.warn(`Non-string key '{Value.repr(k)} = {Value.repr(v)}' found in configuration. It will be ignored.`)
            table[k] = nil
        else
            local key_name = if #config_name == 0 then k else `{config_name}.{k}`
            if schema[k] then
                local k_schema = schema[k]
                if type(k_schema) == "table" then
                    if v and type(v) ~= "table" then
                        Log.error(`'{key_name}' should be a table, but it is a {type(v)}.'`)
                        schema_error()
                    end
                    if not v then
                        table[k] = {}
                        v = table[k]
                    end
                    check_schema(key_name, k_schema, v)
                elseif k_schema == ty_boolean then
                    if v and type(v) ~= "boolean" then
                        Log.warn(`'{key_name}' should be a boolean, but it is a {type(v)}. It will be treated as one.`)
                    end
                    table[k] = not not table[k]
                elseif k_schema == ty_string then
                    if v and type(v) ~= "string" then
                        Log.error(`'{key_name}' should be a string, but it is a {type(v)}.`)
                        schema_error()
                    end
                elseif k_schema == ty_string_list then
                    if v then
                        if type(v) == "string" then
                            table[k] = { table[k] }
                        elseif type(v) == "table" then
                            for k, v in v do
                                if type(k) ~= "number" then
                                    Log.error(`'{key_name}' should be a list, but it is a dictionary.`)
                                    schema_error()
                                end
                                if type(v) ~= "string" then
                                    Log.error(`'{key_name}' should be a list of strings, not of {type(v)}.`)
                                    schema_error()
                                end
                            end
                        else
                            Log.error(`'{key_name}' should be a list, but it is a {type(v)}.`)
                            schema_error()
                        end
                    else
                        table[k] = {}
                    end
                else
                    error("unreachable?")
                end
            else
                Log.warn(`'{key_name}' is not a recognized configuration option. It will be ignored.`)
                table[k] = nil
            end
        end
    end
end

local function merge_config(config, default_config)
    if type(config) == "table" and type(default_config) == "table" then
        local new_table = {}
        for k, v in default_config do
            new_table[k] = v
        end
        for k, v in config do
            if new_table[k] then
                new_table[k] = merge_config(v, new_table[k])
            else
                new_table[k] = v
            end
        end
        return new_table
    elseif config then
        return config
    else
        return default_config
    end
end

local function check_deprecations(config)
    if config.settings.verbose then
        Log.warn("`settings.verbose` option is deprecated: Verbosity may only be set on the command line.")
    end
    if config.settings.debug then
        Log.warn("`settings.debug` option is deprecated: Verbosity may only be set on the command line.")
    end
    if config.settings.caching then
        Log.warn("`settings.caching` option is deprecated: Caching is not supported in crabsoup.")
    end
end

local default_config = TOML.from_string(require("resources")["app/default_config.toml"])
check_schema("", schema, default_config)

function module.load_configuration(config_source)
    local config = TOML.from_string(config_source)
    check_schema("", schema, config)
    local merged = merge_config(config, default_config)
    check_deprecations(merged)
    return merged
end

return module
