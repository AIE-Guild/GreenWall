----------------------------------------------------------------------------
-- Package Definition
----------------------------------------------------------------------------

local VERSION_MAJOR = "SemanticVersion-1.0"
-- MINOR 2: pre-release precedence fixes (build metadata without a pre-release; antisymmetric
-- identifier comparison; larger field sets ranking higher).  The bump is load-bearing, not
-- bookkeeping -- LibStub:NewLibrary returns nil when `oldminor >= minor`, so at minor 1 this
-- fixed copy would silently lose to any other addon's unfixed copy that happened to load first,
-- and the defects would persist with nothing to show for the fix.
local VERSION_MINOR = 2
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
        local pre, meta = suffix:match('^-([%w%.]+)%+?([%w%.]*)$')
        if not pre then
            -- Build metadata may follow the patch directly, with no pre-release at all --
            -- '1.0.0+20130313144700' is a valid version (semver 2.0.0 section 10).  Requiring a
            -- leading '-' rejected the whole version string in that case.
            meta = suffix:match('^%+([%w%.]+)$')
            if not meta then
                return
            end
            pre = ''
        end
        self.pre = split(pre)
        self.meta = split(meta)
        if not (self.pre and self.meta) then
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
            -- Ran out of pre-release fields on the left.  "A larger set of pre-release fields has
            -- a higher precedence than a smaller set" (semver 2.0.0 section 11), so the shorter
            -- side ranks LOWER.  Returning 1 here made 1.0.0-alpha outrank 1.0.0-alpha.1.
            return -1
        elseif not rhs then
            return 1
        elseif type(lhs) == 'number' and type(rhs) == 'string' then
            -- "Numeric identifiers always have lower precedence than non-numeric identifiers."
            return -1
        elseif type(lhs) == 'string' and type(rhs) == 'number' then
            -- Returning -1 here too made the comparison non-antisymmetric: both a < b and b < a
            -- were true, so any ordering built on it depended on argument order.
            return 1
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

