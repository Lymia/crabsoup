--!strict

local builtin_funcs, _G = ...

-- Stored stdlib functions
local error = error
local getfenv = getfenv
local next = next

-- Function definitions for Lua 2.5 API
function _G.dostring(chunk, chunkname, mode, env)
    error("Dynamic code loading is not currently supported.")
end

function _G.nextvar(name: any): (any, any)
    return next(getfenv(0), name)
end

function _G.setglobal(name: string, value: any)
    getfenv(0)[name] = value
end

function _G.getglobal(name: string): any
    return getfenv(0)[name]
end

function _G.setfallback(fallbackname: string, newfallback: any)
    error("setfallback is not supported, and will never be supported. Please use Lua 5.1 metatables instead.", 2)
end

_G.strfind = string.find
_G.strlen = string.len
_G.strsub = string.sub
_G.strlower = string.lower
_G.strupper = string.upper
_G.strrep = string.rep
_G.ascii = string.byte
_G.format = string.format
_G.gsub = string.gsub

_G.abs = math.abs
_G.acos = math.acos
_G.asin = math.asin
_G.atan = math.atan
_G.atan2 = math.atan2
_G.ceil = math.ceil
_G.cos = math.cos
_G.floor = math.floor
_G.log = math.log
_G.log10 = math.log10
_G.max = math.max
_G.min = math.min
_G.sin = math.sin
_G.sqrt = math.sqrt
_G.tan = math.tan
_G.random = math.random
_G.randomseed = math.randomseed

function _G.mod(lhs: number, rhs: number): number
    return lhs % rhs
end
