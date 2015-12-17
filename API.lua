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

An API for guild chat bridging as a transport

--]]-----------------------------------------------------------------------

GreenWallAPI = {}

--- Send a message to the guild confederation.
-- @param message The message to send. Accepts 8-bit data.
function GreenWallAPI.Send(message)
end

--- Insert a handler for addon messages from the guild confederation.
-- @param handler A callback function.
-- @param addon The name of the addon that you want to receive meaasges from
--  (the same one used for the name of the TOC file).  If the value '*' is
--   supplied, messages from all addons will be handled.
-- @param priority A signed integer indicating relative priority, lower value
--  is handled first.  The default is 0.
-- @return The key that can be used to remove the handler. 
function GreenWallAPI.AddHandler(handler, addon, priority)
    -- Validate the arguments
    assert(priority % 1 == 0)
    if addon ~= '*' then
        id = GetAddOnInfo(addon)
        assert(id == addon)
    end
    
    table.insert(gw.api_table, {addon, priority, handler})
    table.sort(gw.api_table, function (a, b) return a[2] < b[2] end)

    return handler
end

