--[[--------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2019 Mark Rogaski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]--------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Package Definition
----------------------------------------------------------------------------

local VERSION_MAJOR = "SemanticVersion-1.0"
local VERSION_MINOR = 1
local SemVer = LibStub:NewLibrary(VERSION_MAJOR, VERSION_MINOR)
if not SemVer then
    return
end

SemVer.__index = SemVer
SemVer.__tostring = SemVer.string

setmetatable(SemVer, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

--- Constructor method.
-- @param s The version string.
-- @return The semantic version object.
function SemVer.new(s)
    local function split(s)
        local tab = {}
        for token in s:gmatch('%w+') do
            if token:match('%a') then
                table.insert(tab, token)
            else
                if token:match('^0%d') then
                    return
                else
                    table.insert(tab, tonumber(token))
                end
            end
        end
        return tab
    end
    
    local self = setmetatable({}, SemVer)
    local major, minor, patch, suffix = s:match('^(%d+)%.(%d+)%.(%d+)(.*)')
    
    if major == nil then
        return
    end
    
    self.major = tonumber(major)
    self.minor = tonumber(minor)
    self.patch = tonumber(patch)
    self.pre = {}
    self.meta = {}
    
    if suffix and suffix ~= '' then
        local valid, pre, meta = suffix:match('^(-([%w%.]+)%+?([%w%.]*))$')
        if valid then
            self.pre = split(pre)
            self.meta = split(meta)
            if not (self.pre and self.meta) then
                return
            end
        else
            return
        end
    end
    
    return self
end


SemVer.__tostring = function (self)
    local function join(sep, ...)
        local arg = {...}
        for i = 1, #arg do
            arg[i] = tostring(arg[i])
        end
        return strjoin(sep, unpack(arg))
    end
    
    local s = join('.', self.major, self.minor, self.patch)
    if #self.pre > 0 then
        s = format('%s-%s', s, join('.', unpack(self.pre)))
    end
    if #self.meta > 0 then
        s = format('%s+%s', s, join('.', unpack(self.meta)))
    end
    return s
end

local function cmp_version(lhs, rhs)
    local function cmp(lhs, rhs)
        if not lhs and not rhs then
            return 0
        elseif not lhs then
            return 1
        elseif not rhs then
            return -1
        elseif type(lhs) == 'number' and type(rhs) == 'string' then
            return -1
        elseif type(lhs) == 'string' and type(rhs) == 'number' then
            return -1
        else
            return lhs == rhs and 0 or lhs < rhs and -1 or 1
        end    
    end
    
    local function max(a, b)
        return a >= b and a or b 
    end

    -- Compare the standard version strings
    for _, key in ipairs({'major', 'minor', 'patch'}) do
        local res = cmp(lhs[key], rhs[key])
        if res ~= 0 then
            return res
        end
    end

    -- Pre-release has lower precedence
    if #lhs.pre == 0 and #rhs.pre > 0 then
        return 1
    elseif #rhs.pre == 0 and #lhs.pre > 0 then
        return -1
    end
    
    -- Compare pre-release strings
    for i = 1, max(#lhs.pre, #rhs.pre) do
        local res = cmp(lhs.pre[i], rhs.pre[i])
        if res ~= 0 then
            return res
        end
    end
    
    return 0
end

SemVer.__eq = function (lhs, rhs)
    return cmp_version(lhs, rhs) == 0
end

SemVer.__lt = function (lhs, rhs)
    return cmp_version(lhs, rhs) < 0
end

SemVer.__le = function (lhs, rhs)
    return cmp_version(lhs, rhs) < 1
end

