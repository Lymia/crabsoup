# Plugin API

The plugin API in crabsoup is based on (and, for the most part, compatible) with the one used in [Soupault](https://soupault.app/).

Plugins are written in Lua 5.1 code, running on the [Luau](https://luau-lang.org/) VM. The reference manual for Lua 5.1 can be found [here](https://www.lua.org/manual/5.1/), and information on the differences between regular Lua 5.1 and Luau may be found [here](https://luau-lang.org/syntax).

## Installing/Running Plugins

### Plugin Discovery

By default, crabsoup looks for plugins in the `plugins/` directory. A file placed at `plugins/site-url.lua` or `plugins/site-url.luau` will be loaded as a widget named `site-url`.

You can override the path at which plugins are found in using the `settings.plugin_dirs` option.

```toml
[settings]
plugin_dirs = ["plugins", "/usr/share/soupault/plugins"]
```

If a file with the same name is found in multiple directories, soupault will use the file from the first directory in the list. Builtin plugins are never loaded using plugin discovery.

You can disable automatic plugin loading by setting `plugin_dirs` to an empty list.

### Explicit Plugin Loading

You can load plugins explicitly instead, which can be used to load a plugin from an unusual plugin or change the name it is available under. This is also needed to override a built-in widget.

Suppose you want the widget of `site-url.lua` to be named `absolute-links`. Add this snippet to soupault.conf:

```toml
[plugins.absolute-links]
file = "plugins/site-url.lua"
```

You can also use the `lua_source` option instead of `file` to directly include Lua code in the configuration file.

### Using `crabsoup-lua`

The `crabsoup-lua` command can be used to load plugins as Lua scripts. This binary exposes a slightly different API that includes functionality for plugin loading, sandboxing and execution - and lacks APIs that are meant to operate on a single page.

The `crabsoup` binary is implemented as pure Lua code, running through the `crabsoup-lua` executor.

## Lua Environment

Crabsoup plugins are run in isolated environments with their own globals tables.

### Standard environment

The default Lua environment contains all the following functions:

* All [standard library functions](https://luau-lang.org/library) exported by Luau.
* Reimplementation of the standard [`io`] and full [`os`] libraries, in addition to the standard [`load`], [`loadfile`], [`loadstring`] and [`dofile`] functions. When possible, these are based off the 5.4 APIs and include new functionality from newer versions. Otherwise, they are based on the Lua 5.1 APIs.
  * As a special exception, no access to the standard input is available.
* A reimplementation of the [`require`] function 
* All functions found in the Plugin API and Compatibility API sections of this document.

[`dofile`]: https://www.lua.org/manual/5.4/manual.html#pdf-dofile
[`io`]: https://www.lua.org/manual/5.4/manual.html#6.8
[`loadfile`]: https://www.lua.org/manual/5.4/manual.html#pdf-loadfile
[`load`]: https://www.lua.org/manual/5.4/manual.html#pdf-load
[`loadstring`]: https://www.lua.org/manual/5.1/manual.html#pdf-loadstring
[`os`]: https://www.lua.org/manual/5.4/manual.html#6.9
[`require`]: https://www.lua.org/manual/5.4/manual.html#pdf-require

All plugins run in this environment.

### Standalone environment

The standalone has the following differences from the standard environment:

* It includes all functions found in the Standalone API section of this document.
* It does not include any functions found in the Compatibility API section.

This is the environment the `crabsoup` binary runs in, and thus allows access to all functionality used to create the program. Any scripts loaded through the `crabsoup-lua` binary are loaded into this environment.

## Plugin API

### Reading this section

APIs marked "*(since soupault 1.0.0)*" are only available since a given soupault version. crabsoup as of version {CRABSOUP_VERSION} attempts to remain compatible with the soupault 4.10.0 API.

APIs marked "*(since crabsoup 0.1.0)*" are only available since a given crabsoup version. This also implies that the method is an extension and is not available in the original soupault.

### Global Variables

The following variables are available in the global namespace for all plugins. All variables in this section are only available for plugins, as they are set by the `crabsoup` runner.

#### page
The root element of the page being worked on.

#### page_file
The path to the page file being worked on, relative to the current directory. (e.g. `"site/about/me.html"`)

#### target_dir
The directory where the processed page file will be saved. (e.g. `"build/about/"`)

#### target_file
The path where the processed page file will be saved. (e.g. `"build/about/me.html"`)

#### nav_path
A list of strings representing the logical navigation path. (e.g. `["foo", "bar"]` for a page at `site/foo/bar/quux.html`)

#### page_url
The URL of the page relative to the webroot. (e.g. `/articles` or `/articles/index.html`, depending on the `clean_urls` setting)

#### config
A table with the configuration options for the active widget.

#### soupault_config
A table with the complete contents of the `soupault.toml` table.

#### site_index
A table containing the data extracted during the site index phase.

#### index_entry
The index entry of the current page, if `index.index_first` is enabled.

#### site_dir
The path to the site sources.

#### build_dir
The path to the output directory.

#### persistent_data
A table for values supposed to be persistent between different plugin runs.

#### global_data
A table for values shared between all plugins and hooks.

#### soupault_pass
The website build pass, when the two-pass workflow is enabled. Always 0 if `index.index_first = false`, otherwise 1 on the first pass and 2 on the second pass.

### Standard Library Extensions

The following functions are added to the standard library of Luau. All functions here are new to crabsoup and are not available in soupault.

#### math.isnan(value: number): boolean

Returns `true` only if `value` is an `NaN` value of some variety.

#### math.isinf(value: number): boolean

Returns `true` only if `value` is a infinite value of some variety.

#### math.isfinite(value: number): boolean

Returns `true` only if `value` is neither infinite nor `NaN`.

#### string.trim(str: string): string

Removes leading and trailing whitespace from the string.

#### string.startswith(str: string, prefix: string): string

Checks is string starts with prefix. For example, `string.startswith("hello", "hell")` is true and `string.startswith("maintenance", "fun")` is false.

#### string.endswith(str: string, suffix: string): string

Like string.startswith, but checks if a string ends with given suffix.

### HTML Library

[TODO]

### Regex Library

[TODO]

### String Library

#### String.truncate(str: string, length: number, add_trailer: string?): string

Returns the first length characters of the string, counting in UTF-8 characters.

For strings that contain invalid Unicode characters, it instead counts bytes rather than codepoints.

If `add_trailer` is not nil, it is added to the end of the string in the case that it is truncated. *(The `add_trailer` parameter is new in crabsoup 0.1.0)*

#### String.slugify_soft(str: string): string

Replaces all whitespace in the string with hyphens to make it a valid HTML id.

#### String.slugify_ascii(str: string): string

Example: String.slugify_ascii("My Heading") produces "my-heading"

Replaces all characters other than English letters and digits with hyphens, exactly like the ToC widget.

#### String.render_template(template_string: string, env: table?): string

Renders data using a [minijinja](https://docs.rs/minijinja/latest/minijinja/) template.

Example:

```lua
env = {}
env["greeting"] = "hello"
env["addressee"] = "world"
s = String.render_template("{{greeting}} {{addressee}}", env)
```

#### String.base64_encode(str: string): string

Encodes a string in Base64.

#### String.base64_decode(str: string): string

Decodes Base64 data.

#### String.url_encode(str: string, exclude: {string}?): string

Encodes a string using URL percent-encoding as per RFC3986.

All characters except ASCII letters, hyphens, underscores, and tildes are replaced with percent-encoded versions (e.g. space is %20).

You can also supply a list of characters to exclude from encoding: String.url_encode(string, {"?", "&"}).

#### String.url_decode(str: string): string

Decodes percent-encoded URL strings.

## Compatibility APIs

These APIs are included in Soupault, but are no longer required due to crabsoup using Lua 5.1, or are otherwise obsolete. These functions are *not* deprecated and will never be removed or otherwise made harder to use.

### Lua 2.5 APIs

The following functions are reimplemented from Lua 2.5:

* `dostring`
* `nextvar`
* `setglobal`
* `getglobal`
* `strfind`
* `strlen`
* `strsub`
* `strlower`
* `strupper`
* `strrep`
* `ascii`
* `format` (not in `string`)
* `gsub` (not in `string`)
* `abs` (not in `math`)
* `acos` (not in `math`)
* `asin` (not in `math`)
* `atan` (not in `math`)
* `atan2` (not in `math`)
* `ceil` (not in `math`)
* `cos` (not in `math`)
* `acos` (not in `math`)
* `floor` (not in `math`)
* `log` (not in `math`)
* `log10` (not in `math`)
* `max` (not in `math`)
* `min` (not in `math`)
* `sin` (not in `math`)
* `sqrt` (not in `math`)
* `tan` (not in `math`)
* `random` (not in `math`)
* `randomseed` (not in `math`)

### String Library

Most of the `String` library from Soupault is redundant with additions to the standard library by either crabsoup, luau, or just newer Lua versions. The following are equivalent to the following functions or language constructs:

* `String.is_valid_utf8(str)` = `utf8.len(str)` (this function returns `nil` on invalid strings and a number on valid strings)
* `String.length_ascii(str)` = `#str`
* `String.truncate_ascii(str, n)` = `str:sub(1, n)`
* `String.to_number(str)` = `tonumber(str)`
* `String.join(sep, list)` = `table.join(list, sep)`

The following functions have been moved to being extensions of the builtin `string` library (and are thus available as string methods):

* `String.trim(str)` = `str:trim()` or `string.trim(str)`
* `String.ends_with(str)` = `str:endswith()` or `string.endswith(str)`
* `String.starts_with(str)` = `str:startswith()` or `string.startswith(str)`

The following functions are not redundant, but are not very useful.

#### String.length(str: string): number

Returns the count of UTF-8 characters in a string. For strings that contain invalid Unicode characters, it behaves like String.length_ascii() and measures their length in bytes instead.

This is rarely more useful than `#str` in practice, as string lengths are rarely essential.
