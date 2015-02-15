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
-- @return An initialized GwChannel instance.
function GwChannel:new()
    local self = {}
    setmetatable(self, GwChannel)
    return self:initialize()
end

function GwChannel:initialize()
    self.frame_table = {}
    self.version = 0
    self.name = ''
    self.password = ''
    self.number = 0
    self.stale = true
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
    self.version = version
    self.name = name
    self.password = password and password or ''
    self.stale = false
    gw.Debug(GW_LOG_INFO, 'configured channel; channel=%s, password=%s, version=%d, stale=%s',
            gw.Redact(self.name), gw.Redact(self.password), self.version, tostring(self.stale));
end


--- Clear the channel configuration.
function GwChannel:clear()
    gw.Debug(GW_LOG_INFO, 'clearing channel; number=%d, channel=%s', self.number, gw.Redact(self.name))
    self:leave()
    self:initialize()
end


--- Mark the channel as stale.
function GwChannel:age()
    self.stale = true
    gw.Debug(GW_LOG_DEBUG, 'marked stale; number=%d, channel=%s', self.number, gw.Redact(self.name))
end


--- Test if the channel is configured.
-- @return True if configured, false otherwise.
function GwChannel:is_configured()
    gw.Debug(GW_LOG_DEBUG, 'number=%d, name=%s, password=%s, version=%d, stale=%s',
            self.number, gw.Redact(self.name), gw.Redact(self.password), self.version, tostring(self.stale))
    return self.name and self.name ~= ''
end

--- Check if a connection exists to the custom channel.
-- @return True if connected, otherwise false.
function GwChannel:is_connected()
    gw.Debug(GW_LOG_DEBUG, 'number=%d, name=%s', self.number, gw.Redact(self.name))
    if self:is_configured() then
        self.number = GetChannelName(self.name)
        gw.Debug(GW_LOG_DEBUG, 'set number=%d', self.number)
        if self.number == 0 then
            return false
        else
            return true
        end
    end
end

--- Check if channel configuration is stale.
-- @return True if stale, false otherwise.
function GwChannel:is_stale()
    gw.Debug(GW_LOG_DEBUG, 'number=%d, name=%s, password=%s, version=%d, stale=%s',
            self.number, gw.Redact(self.name), gw.Redact(self.password), self.version, tostring(self.stale))
    return self.stale
end


--- Join a bridge channel.
-- @return True if connection success, false otherwise.
function GwChannel:join()

    -- Only join if we have the channel details
    if not self:is_configured() then
        return false
    end

    if not self:is_connected() then

        gw.Debug(GW_LOG_INFO, 'joining channel; channel=%s, password=%s',
                gw.Redact(self.name), gw.Redact(self.password))
        JoinTemporaryChannel(self.name, self.password)
        local number = GetChannelName(self.name)

        if number == 0 then
    
            gw.Error('cannot create communication channel: %s', gw.Redact(self.name))
            self.stats.fconn = self.stats.fconn + 1
            return false
    
        else
    
            self.number = number
            self.stats.sconn = self.stats.sconn + 1
            gw.Debug(GW_LOG_NOTICE, 'joined channel; number=%d, name=%s, password=%s',
                    self.number, gw.Redact(self.name), gw.Redact(self.password))
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
                            gw.Debug(GW_LOG_INFO, 'hiding channel: number=%d, name=%s, frame=%s', 
                                    self.number, gw.Redact(self.name), frame)
                            ChatFrame_RemoveChannel(frame, self.name)
                        end
                    end
                end
            end
    
            -- Gratuitous officer announcement
            gw.SendLocal(GW_MTYPE_RESPONSE, 'officer')
    
            return true
    
        end
        
    end

end

--- Leave a bridge channel.
-- @return True if a disconnection occurred, false otherwise.
function GwChannel:leave()
    if self:is_connected() then
        gw.Debug(GW_LOG_INFO, 'leaving channel; number=%d, channel=%s, password=%s', 
                self.number, gw.Redact(self.name), gw.Redact(self.password))
        LeaveChannelByName(self.name)
        self.stats.leave = self.stats.leave + 1
        self.number = 0
        return true
    else
        return false
    end
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
    local message = self:al_encode(type, ...)
    gw.Debug(GW_LOG_INFO, 'channel=%d, type=%d, message=%s', self.number, type, message)
    return self:tl_send(type, message)
end

function GwChannel:al_encode(type, ...)
    local arg = {...}
    local message
    if type == GW_MTYPE_BROADCAST then
        assert(#arg >= 1)
        assert(#arg <= 3)
        return strjoin(':', arg[1], arg[2] or '', arg[3] or '')
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
    gw.Debug(GW_LOG_DEBUG, 'enqueued segment: %s', segment)
    return #self.tx_queue
end

--- Remove a segment from the channel transmit queue.
-- @return Segment removed from the queue or nil if queue is empty.
function GwChannel:tl_dequeue()
    local segment = tremove(self.tx_queue, 1)
    if segment then
        gw.Debug(GW_LOG_DEBUG, 'dequeued segment: %s', segment)
    end
    return segment
end

--- Transmit all messages in the channel transmit queue.
-- @return Number of messages flushed.
function GwChannel:tl_flush()
    gw.Debug(GW_LOG_INFO, 'servicing transmit queue; channel=%d, %d message(s) queued.', self.number, #self.tx_queue)
    if self:is_connected() then
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
                gw.Debug(GW_LOG_NOTICE, 'channel=%d, segment=%s', self.number, segment)
                SendChatMessage(segment, 'CHANNEL', nil, self.number)
                self.stats.txcnt = self.stats.txcnt + 1
                count = count + 1
            else
                break
            end
        end
        return count
    else
        gw.Debug(GW_LOG_WARNING, 'channel=%d, not connected.', self.number)
        return 0
    end
end


--[[-----------------------------------------------------------------------

Receive Methods

--]]-----------------------------------------------------------------------

--- Handler for data received on a channel.
-- @param f A callback function.
-- @param ... The API event arguments.
-- @return The return value of f applied to the data.
function GwChannel:receive(f, ...)
    local sender, guild_id, type, message = self:tl_receive(...)
    if type and sender ~= gw.player and guild_id ~= gw.config.guild_id then
        gw.Debug(GW_LOG_INFO, 'channel=%d, type=%d, sender=%s, message=%s', self.number, type, sender, message)
        local content = { self:al_decode(type, message) }
        return f(type, guild_id, content, {...})
    end
end

function GwChannel:al_decode(type, message)
    gw.Debug(GW_LOG_DEBUG, 'type=%d, message=%s', type, message)
    if type == GW_MTYPE_BROADCAST then
        return strsplit(':', message)
    else
        return message
    end
end

function GwChannel:tl_receive(...)
    local segment, sender = select(1, ...)
    sender = gw.GlobalName(sender)
    gw.Debug(GW_LOG_NOTICE, 'channel=%d, sender=%s, segment=%s', self.number, sender, segment)
    self.stats.rxcnt = self.stats.rxcnt + 1
    
    -- Check the segment hash
    if sender == gw.player then
        local hash = crc.Hash(segment)
        if self.tx_hash[hash] and self.tx_hash[hash] > 0 then
            gw.Debug(GW_LOG_DEBUG, 'channel=%d, tx_hash[0x%04X] == %d', self.number, hash, self.tx_hash[hash])
            self.tx_hash[hash] = self.tx_hash[hash] - 1
            if self.tx_hash[hash] <= 0 then
                self.tx_hash[hash] = nil
            end
        else
            gw.Debug(GW_LOG_WARNING, 'channel=%d, tx_hash[0x%04X] not found', self.number, hash)
            gw.Error('Message corruption detected.  Please disable add-ons that might modify messages on channel %d.', self.number)
        end
    end
    
    -- Process the segment
    local opcode, guild_id, _, message = strsplit('#', segment, 4)
    gw.Debug(GW_LOG_DEBUG, 'opcode=%s, guild_id=%s, message=%s', opcode, guild_id, message)
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
    end
    return sender, guild_id, type, message
end

