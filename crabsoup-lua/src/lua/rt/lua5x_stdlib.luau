local builtin_funcs = ...

-- Reimplement base library functions
_G.loadstring = builtin_funcs.crabsoup.loadstring
