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


--[[-----------------------------------------------------------------------

Class Variables

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
-- @return True is the hold-down is still in effect, false otherwise.
function GwHoldDown:hold()
    local t = time()
    return t < self.expiry
end

