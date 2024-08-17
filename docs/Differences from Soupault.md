# Differences from Soupault

While crabsoup makes an effort to be compatible with soupault-based websites with few changes, it only aims for "practical" compatibility with common functionality. This is a non-exhaustive list of changes to be aware of.

## Lua Plugins

While most plugins in practice should work without modification from Soupault, a few major differences should be kept in mind:

### UTF-8 Encoding

Due to being written in Rust, crabsoup is a natively unicode program with a strong preference to work with UTF-8 encoded text when possible. As such, many APIs may unexpectedly fail when used on non-Unicode strings when soupault would not.

### Removed Lua 2.5 APIs

While crabsoup makes an best effort to implement all Lua 2.5 APIs, a few are simply too different from Lua 5.1 to work. `setfallback` notably, throws an error since it cannot be implemented in Lua 5.1

### Upvalues

Lua 5.1 supports proper closures, which changes the semantics of very rare Lua code.

```lua
local upvalue = 10
local function closure()
    upvalue = 20 -- this sets the `upvalue` local in Lua 5.1 and the `upvalue` global in Lua 2.5
end
closure()
print(upvalue) -- This returns '10' in Lua 2.5 and '20' in Lua 5.1
```

Don't write code like this even for soupault, it's extremely confusing.

### Globals Locking

Most global tables such as `Sys` are locked, and cannot be modified by plugin code. This is done because the `crabsoup` binary is written in Lua, and thus, shares the same global tables.

Please rewrite your code to not monkey patch global tables.

### Weak HTML Parent References

The HTML library used by Crabsoup uses weak references to access the parent node of elements. Therefore, `HTML.parent` may return `nil` if the parent element of a node has been garbage collected.

This is unlikely to happen in practice, as in practice, you only access the parent of elements whose roots are stored in another variable (such as the `page` global).

### HTML Chaining

HTML chaining (where you can use `nil` in place of any `NodeRef` and have the function return `nil` instead of raising an error) is not supported in crabsoup. It would make the type signatures for the `HTML` library significantly more complicated, and has little benefits (only two functions possibly return `nil` in place of a node: `HTML.parent` and `HTML.select_one`, both of which manual checking is reasonable for).
    