--!strict

local _, _G = ...

-- Function definitions for Lua 2.5 API
local function return_helper(success: boolean, ...: unknown): ...unknown
    if success then
        if #{ ... } == 0 then
            return true
        else
            return ...
        end
    else
        return nil
    end
end
function _G.dostring(chunk, chunkname, mode, env)
    if not env then
        env = getfenv(2)
    end
    local func, err = loadstring(chunk, chunkname, mode, env)
    if func then
        return return_helper(pcall(func))
    else
        error(err)
    end
end

function _G.nextvar(name: any): (any, any)
    return next(getfenv(0), name)
end

function _G.setglobal<T>(name: string, value: T)
    getfenv(0)[name] = value
end

function _G.getglobal<T>(name: string): T
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
