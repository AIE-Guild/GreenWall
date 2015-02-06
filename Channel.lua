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

Imported Libraries

--]]-----------------------------------------------------------------------

local crc = LibStub:GetLibrary("Hash:CRC:16ccitt-1.0")


--[[-----------------------------------------------------------------------

Class Variables

--]]-----------------------------------------------------------------------

GwChannel = {}
GwChannel.__index = GwChannel


--- GwChannel constructor function.
-- @param type GW_CTYPE_GUILD or GW_CTYPE_OFFICER.
-- @return An initialized GwChannel instance.
function GwChannel:new(type)
    assert(type == GW_CTYPE_GUILD or type == GW_CTYPE_OFFICER)
    local self = {}
    setmetatable(self, GwChannel)
    self.frame_table = {}
    self.type = type
    self.version = 0
    self.name = ''
    self.password = ''
    self.number = 0
    self.tx_queue = {}
    self.tx_hash = {}
    self.stats = {
        txcnt = 0,
        rxcnt = 0,
        sconn = 0,
        fconn = 0,
        leave = 0,
        disco = 0,
    }
    return self
end


--[[-----------------------------------------------------------------------

Channel Management Methods

--]]-----------------------------------------------------------------------

--- Configure the channel.
-- @param version Messaging version.
-- @param name Name of the channel.
-- @param password Password for the channel. (optional)
function GwChannel:configure(version, name, password)
    assert(version == 1)
    assert(name and name ~= '')
    self:leave()
    self.version = version
    self.name = name
    self.password = password and password or ''
end

--- Test if the channel is configured.
-- @return True if configured, false otherwise.
function GwChannel:isConfigured()
    return self.name and self.name ~= ''
end

--- Join a bridge channel.
-- @return True if connection success, false otherwise.
function GwChannel:join()

    if not self:isConfigured() then
        return false
    end

    local number = GetChannelName(self.name)
    
    if number == 0 then
        JoinTemporaryChannel(self.name, self.password)
        number = GetChannelName(self.name)
    end
    
    if chan.number == 0 then

        gw.Error('cannot create communication channel: %s', self.name)
        self.stats.fconn = self.stats.fconn + 1
        return false

    else

        self.number = number
        self.stats.sconn = self.stats.sconn + 1
        gw.Debug(GW_LOG_INFO, 'chan_join[%d]: name=<<%04X>>', self.number, crc.Hash(self.name))
        gw.Write('Connected to confederation on channel %d.', self.number)
              
        --
        -- Hide the channel
        --
        for i = 1, 10 do
            GwChannel.frame_table = { GetChatWindowMessages(i) }
            for j, v in ipairs(GwChannel.frame_table) do
                if v == self.name then
                    local frame = format('ChatFrame%d', i)
                    if _G[frame] then
                        gw.Debug(GW_LOG_INFO, 'chan_join[%d]: hiding channel: name=<<%04X>>, frame=%s', 
                                self.number, crc.Hash(self.name), frame)
                        ChatFrame_RemoveChannel(frame, self.name)
                    end
                end
            end
        end

        return true

    end

end

--- Leave a bridge channel.
-- @return True if a disconnection occurred, false otherwise.
function GwChannel:leave()
    if self:isConnected() then
        gw.Debug(GW_LOG_INFO, 'chan_leave[%d]: name=<<%04X>>', self.number, crc.Hash(self.name))
        LeaveChannelByName(self.name)
        self.stats.leave = self.stats.leave + 1
        self.number = 0
        return true
    else
        return false
    end
end

--- Check if a connection exists to the custom channel.
-- @return True if connected, otherwise false.
function GwChannel:isConnected()
    if self.name then
        local number = GetChannelName(self.name)
        gw.Debug(GW_LOG_DEBUG, 'chan_test[%d]: name=<<%04X>>, number=%d', self.number, crc.Hash(self.name), number)
        if number ~= 0 then
            self.number = number
        end
        return true
    end
    return false            
end


--[[-----------------------------------------------------------------------

Transmit Methods

--]]-----------------------------------------------------------------------

--- Sends an encoded message on the shared channel.
-- @param type The message type.
--   Accepted values are: 
--     GW_MTYPE_CHAT
--     GW_MTYPE_ACHIEVEMENT
--     GW_MTYPE_BROADCAST
--     GW_MTYPE_NOTICE
--     GW_MTYPE_REQUEST
--     GW_MTYPE_ADDON
-- @param message Text of the message.
function GwChannel:send(type, ...)
    -- Apply adaptation layer encoding
    local message = self:al_encode(type, unpack(arg))
    gw.Debug(GW_LOG_DEBUG, 'channel_send[%d]: type=%d, message=%s', self.number, type, message)
    return self:tl_send(type, message)
end

function GwChannel:al_encode(type, ...)
    local message
    if type == GW_MTYPE_BROADCAST then
        assert(#arg == 3)
        return strjoin(':', tostring(arg[1]), tostring(arg[2]), tostring(arg[3]))
    else
        assert(#arg == 1)
        return arg[1]
    end
end

function GwChannel:tl_send(type, message)
    local opcode
    if type == GW_MTYPE_CHAT then
        opcode = 'C'
    elseif type == GW_MTYPE_ACHIEVEMENT then
        opcode = 'A'
    elseif type == GW_MTYPE_BROADCAST then
        opcode = 'B'
    elseif type == GW_MTYPE_NOTICE then
        opcode = 'N'
    elseif type == GW_MTYPE_REQUEST then
        opcode = 'R'
    elseif type == GW_MTYPE_ADDON then
        opcode = 'M'
    else
        gw.Debug(GW_LOG_ERROR, 'unknown message type: %d', type)
        return
    end
    
    -- Format the message segment
    local segment = strsub(strjoin('#', opcode, gw.config.guild_id, '', message), 1, GW_MAX_MESSAGE_LENGTH)
    
    -- Send the message
    self:tl_enqueue(segment)
    self:tl_flush()
end

--- Add a segment to the channel transmit queue.
-- @param segment Segment to enqueue.
-- @return Number of segments in queue after the insertion.
function GwChannel:tl_enqueue(segment)
    tinsert(self.tx_queue, segment)
    return #self.tx_queue
end

--- Remove a segment from the channel transmit queue.
-- @return Segment removed from the queue or nil if queue is empty.
function GwChannel:tl_dequeue()
    return tremove(self.tx_queue, 1)
end

--- Transmit all messages in the channel transmit queue.
-- @return Number of messages flushed.
function GwChannel:tl_flush()
    gw.Debug(GW_LOG_DEBUG, 'tl_flush[%d]: servicing transmit queue; %d message(s) queued.', self.number, #self.tx_queue)
    if self:isConnected() then
        local count = 0
        while true do
            local segment = self:tl_dequeue()
            if segment then
                -- Record the segment hash
                local hash = crc.Hash(segment)
                if self.tx_hash[hash] == nil then
                    self.tx_hash[hash] = 1
                else
                    self.tx_hash[hash] = self.tx_hash[hash] + 1
                end
                -- Send the segment
                gw.Debug(GW_LOG_DEBUG, 'tl_flush[%d]: Tx<%s, %s>', self.number, gw.player, segment)
                SendChatMessage(segment, 'CHANNEL', nil, self.number)
                self.stats.txcnt = self.stats.txcnt + 1
                count = count + 1
            else
                break
            end
        end
    else
        gw.Debug(GW_LOG_WARNING, 'tl_flush[%d]: not connected.', self.number)
        return 0
    end
end


--[[-----------------------------------------------------------------------

Receive Methods

--]]-----------------------------------------------------------------------

--- Handler for data received on a channel.
-- @param event The API event name.
-- @param f A callback function.
-- @param ... The API event arguments.
-- @return The return value of f applied to the data.
function GwChannel:receive(event, f, ...)
    local guild_id, type, message = self:tl_receive(...)
    local t = { self:al_decode(type, message) }
    return f(self.number, type, guild_id, arg, unpack(t))
end

function GwChannel:al_decode(type, message)
    if type == GW_MTYPE_BROADCAST then
        return strsplit(':', message)
    else
        return message
    end
end

function GwChannel:tl_receive(...)
    local segment, sender = select(1, ...)
    sender = gw.GlobalName(sender)
    gw.Debug(GW_LOG_DEBUG, 'tl_receive[%d]: Rx<%s, %s>', self.number, sender, segment)
    
    -- Check the segment hash
    local hash = crc.Hash(segment)
    if self.tx_hash[hash] and self.tx_hash[hash] > 0 then
        gw.Debug(GW_LOG_DEBUG, 'tl_receive[%d]: tx_hash[0x%04X] == %d', self.number, hash, self.tx_hash[hash])
        self.tx_hash[hash] = self.tx_hash[hash] - 1
        if self.tx_hash[hash] <= 0 then
            self.tx_hash[hash] = nil
        end
    else
        gw.Debug(GW_LOG_WARNING, 'tl_receive[%d]: tx_hash[0x%04X] not found', self.number, hash)
        gw.Error('Message corruption detected.  Please disable add-ons that might modify messages on channel %d.', self.number)
    end
    
    -- Process the segment
    local opcode, guild_id, _, message = strsplit('#', segment, 4)
    local type
    if opcode == 'C' then
        type = GW_MTYPE_CHAT
    elseif opcode == 'A' then
        type = GW_MTYPE_ACHIEVEMENT
    elseif opcode == 'B' then
        type = GW_MTYPE_BROADCAST
    elseif opcode == 'N' then
        type = GW_MTYPE_NOTICE
    elseif opcode == 'R' then
        type = GW_MTYPE_REQUEST
    elseif opcode == 'M' then
        type = GW_MTYPE_ADDON
    else
        gw.Debug(GW_LOG_ERROR, 'unknown segment opcode: %s', opcode)
        return
    end
    return guild_id, type, message
end

