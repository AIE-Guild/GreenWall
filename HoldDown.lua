--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2015 Mark Rogaski

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

--]]-----------------------------------------------------------------------

GwHoldDown = {}
GwHoldDown.__index = GwHoldDown

--- GwHoldDown constructor function.
-- @param interval The length, in seconds, of the hold-down interval.
-- @return An initialized GwHoldDown instance.
function GwHoldDown:new(interval)
    local self = {}
    setmetatable(self, GwHoldDown)
    self.interval = interval
    self.expiry = 0
    return self
end

--- Set the start of the hold-down interval.
-- @return The time at which the interval will end.
function GwHoldDown:set()
    local t = time()
    self.expiry = t + self.interval
    return self.expiry
end

--- Clear the hold-down timer.
-- @return The time at which the interval will end.
function GwHoldDown:clear()
    self.expiry = 0
    return self.expiry
end

--- Test the hold-down status.
-- @return True if a hold-down is in effect, false otherwise.
function GwHoldDown:hold()
    local t = time()
    return self.expiry > t
end


GwHoldDownCache = {}
GwHoldDownCache.__index = GwHoldDownCache

--- GwHoldDownCache constructor function.
-- @param interval The length, in seconds, of the hold-down interval.
-- @param soft_max Table size threshold for compaction.
-- @param hard_max Limit on table size.
-- @return An initialized GwHoldDownCache instance.
function GwHoldDownCache:new(interval, soft_max, hard_max)
    local self = {}
    setmetatable(self, GwHoldDownCache)
    self.interval = interval
    self.soft_max = soft_max
    self.hard_max = hard_max
    self.cache = {}
    return self
end

--- Test the hold-down status of an element.
-- @return True if a hold-down is in effect, false otherwise.
function GwHoldDownCache:hold(s)
    local t = time()
    local rv = false
    
    -- Check for hold-down
    if self.cache[s] == nil then
        self.cache[s] = t + self.interval
    else
        if self.cache[s] > t then
            rv = true
        else
            table.remove(self.cache, s)
        end
    end
    
    -- Prune if necessary
    if #self.cache > self.soft_max then
        for k, v in pairs(self.cache) do
            if v > t then
                table.remove(self.cache, k)
            end
        end
    end
    
    -- Hard prune if necessary
    if #self.cache > self.hard_max then
        local index = {}
        for k, ts in pairs(self.cache) do
            table.insert(index, {ts, k})
        end
        table.sort(index, function(a, b) return a[1] < b [1] end)
        for i = self.hard_max, #index do
            table.remove(self.cache, index[i][2])
        end
    end
    
    return rv
end

