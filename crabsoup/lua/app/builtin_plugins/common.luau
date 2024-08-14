local plugins = {}

local function nyi(name)
    plugins[name] = function(globals)
        Log.error(`Built-in widget '{name}' is not yet implemented!`)
    end
end

nyi("include")
nyi("insert_html")
nyi("exec")
nyi("preprocess_element")
nyi("title")
nyi("footnotes")
nyi("toc")
nyi("breadcrumbs")
nyi("delete_element")
nyi("wrap")
nyi("relative_links")
nyi("absolute_links")

return plugins
