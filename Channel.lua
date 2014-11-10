--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2014 Mark Rogaski

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

GwChannel = {}
GwChannel.__index = GwChannel

--- GwChannel constructor function.
-- @param name The name of the custom channel.
-- @param password The password for the custom channel (optional). 
-- @return An initialized GwChannel instance.
function GwChannel:new(name, password)
    local self = {}
    setmetatable(self, GwChannel)
    self.name = name
    self.password = password
    self:initialize()
    return self
end

--- Initialize a GwChannel object with the default attributes and state.
-- @return The initialized GwChannel instance.
function GwChannel:initialize()
    self.number = 0
    self.configured = false
    self.dirty = false
    self.owner = false
    self.handoff = false
    self.queue = {}
    self.tx_hash = {}
    self.stats = {
        sconn = 0,
        fconn = 0,
        leave = 0,
        disco = 0
    }
    return self
end

--- Check if a connection exists to the custom channel.
-- @return True if connected, otherwise false.
function GwChannel:isConnected()
    if self.name then
        local number = GetChannelName(self.name)
        gw.Debug(GW_LOG_DEBUG, format('conn_check: chan_name=<<%04X>>, chan_id=%d', crc.Hash(self.name), number))
        if number ~= 0 then
            self.number = number
            return true
        end
    end
    return false            
end

