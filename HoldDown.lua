--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2020 Mark Rogaski

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
-- @param limit The maximum hold time when the continue method is invoked.
-- If no value is supplied, the interval value is used.
-- @return An initialized GwHoldDown instance.
function GwHoldDown:new(interval, limit)
    assert(type(interval) == 'number')
    assert(type(limit) == 'number' or limit == nil)
    local self = {}
    setmetatable(self, GwHoldDown)
    self.interval = interval
    if limit then
        self.limit = limit
    else
        self.limit = interval
    end
    self.timestamp = 0
    self.scale = 0
    return self
end

--- Update the timer interval.
-- @param interval The length, in seconds, of the hold-down interval.
-- @param limit The maximum hold time when the continue method is invoked.
-- @return The GwHoldDown instance.
function GwHoldDown:set(interval, limit)
    assert(type(interval) == 'number')
    gw.Debug(GW_LOG_DEBUG, 'hold-down set; timer=%s, interval=%d, limit=%s', tostring(self), interval, tostring(limit))
    self.interval = interval
    if limit then
        self.limit = limit
    else
        self.limit = interval
    end
    return self
end

--- Start the hold-down interval.
-- @param f (optional) A callback function that will be called when the timer expires.
-- @return The time at which the interval will end.
function GwHoldDown:start(f)
    local function handler(frame, elapsed)
        if not self:hold() then
            gw.Debug(GW_LOG_NOTICE, 'hold-down expired; timer=%s', tostring(self))
            if type(f) == 'function' then
                gw.Debug(GW_LOG_NOTICE, 'triggered hold-down callback; function=%s', tostring(f))
                f()
            end
            frame:SetScript('OnUpdate', nil)
        end
    end

    local t = time()
    local expiry = t + self.interval
    self.timestamp = t
    self.scale = 0

    local frame = CreateFrame('frame')
    frame:SetScript('OnUpdate', handler)

    gw.Debug(GW_LOG_NOTICE, 'hold-down start; timer=%s, timestamp=%d, expiry=%d, function=%s',
            tostring(self), self.timestamp, expiry, tostring(f))
    return expiry
end

--- Continue the hold down, scaling the interval.
function GwHoldDown:continue()
    -- Pass-through for first invocation
    if self.timestamp == 0 then
        return self:start()
    end

    -- Increase scaling factor
    if self.interval * 2 ^ (self.scale + 1) <= self.limit then
        self.scale = self.scale + 1
    end

    -- Set the timer
    local t = time()
    local expiry = t + self.interval * 2 ^ self.scale
    self.timestamp = t

    gw.Debug(GW_LOG_NOTICE, 'hold-down continue; timer=%s, timestamp=%d, scale=%d, expiry=%d',
            tostring(self), self.timestamp, self.scale, expiry)

    return expiry
end

--- Clear the hold-down timer.
function GwHoldDown:clear()
    self.timestamp = 0
    self.scale = 0
    gw.Debug(GW_LOG_NOTICE, 'hold-down cleared; timer=%s', tostring(self))
end

--- Test the hold-down status.
-- @return True if a hold-down is in effect, false otherwise.
function GwHoldDown:hold()
    if self.timestamp > 0 then
        local t = time()
        return self.timestamp + self.interval * 2 ^ self.scale > t
    else
        return false
    end
end


GwHoldDownCache = {}
GwHoldDownCache.__index = GwHoldDownCache

--- GwHoldDownCache constructor function.
-- @param interval The length, in seconds, of the hold-down interval.
-- @param soft_max Table size threshold for compaction.
-- @param hard_max Limit on table size.
-- @return An initialized GwHoldDownCache instance.
function GwHoldDownCache:new(interval, soft_max, hard_max)
    assert(type(interval) == 'number')
    assert(type(soft_max) == 'number')
    assert(type(hard_max) == 'number')
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
        self.cache[s] = t
        gw.Debug(GW_LOG_DEBUG, 'cache miss; target=%s, cache=%s', s, tostring(self))
    else
        gw.Debug(GW_LOG_DEBUG, 'cache hit; target=%s, cache=%s', s, tostring(self))
        if self.cache[s] > t + self.interval then
            rv = true
        else
            self.cache[s] = nil
            gw.Debug(GW_LOG_DEBUG, 'cache expire; target=%s, cache=%s', s, tostring(self))
        end
    end

    -- Prune if necessary
    if #self.cache > self.soft_max then
        for k, v in pairs(self.cache) do
            if v > t + self.interval then
                table.remove(self.cache, k)
                gw.Debug(GW_LOG_DEBUG, 'cache soft prune; target=%s, cache=%s', k, tostring(self))
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
            gw.Debug(GW_LOG_DEBUG, 'cache hard prune; target=%s, cache=%s', index[i][2], tostring(self))
        end
    end

    return rv
end

