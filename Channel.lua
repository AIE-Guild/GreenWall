--[[-----------------------------------------------------------------------

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

--]]-----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Imported Libraries

--]]-----------------------------------------------------------------------

local crc = LibStub:GetLibrary("Hash:CRC:16ccitt-1.0")
local base64 = LibStub:GetLibrary("Encoding:Hash:Base64BCA-1.0")


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
    self.cversion = 0
    self.name = ''
    self.password = ''
    self.number = 0
    self.stale = true
    self.fdelay = GwHoldDown:new(GW_CHANNEL_FAILURE_HOLD, GW_CHANNEL_FAILURE_HOLD_MAX)
    self.tx_queue = {}
    self.tx_hash = {}
    self.rx_queue = {}
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
-- @param cversion Configuration version.
-- @param name Name of the channel.
-- @param password Password for the channel. (optional)
function GwChannel:configure(cversion, name, password)
    assert(cversion == 1)
    assert(name and name ~= '')
    self.cversion = cversion
    self.name = name
    self.password = password and password or ''
    self.stale = false
    gw.Debug(GW_LOG_INFO, 'configured channel; channel=%s, password=%s, cversion=%d, stale=%s',
            gw.Redact(self.name), gw.Redact(self.password), self.cversion, tostring(self.stale));
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
    gw.Debug(GW_LOG_DEBUG, 'number=%d, name=%s, password=%s, cversion=%d, stale=%s',
            self.number, gw.Redact(self.name), gw.Redact(self.password), self.cversion, tostring(self.stale))
    return self.name and self.name ~= ''
end

--- Check if a connection exists to the custom channel.
-- @return True if connected, otherwise false.
function GwChannel:is_connected()
    gw.Debug(GW_LOG_DEBUG, 'checking number=%d, name=%s', self.number, gw.Redact(self.name))
    if self:is_configured() then
        self.number = GetChannelName(self.name)
        gw.Debug(GW_LOG_DEBUG, 'confirmed number=%d, name=%s', self.number, gw.Redact(self.name))
        if self.number == 0 then
            return false
        else
            return true
        end
    else
        return false
    end
end

--- Check if channel configuration is stale.
-- @return True if stale, false otherwise.
function GwChannel:is_stale()
    gw.Debug(GW_LOG_DEBUG, 'number=%d, name=%s, password=%s, cversion=%d, stale=%s',
            self.number, gw.Redact(self.name), gw.Redact(self.password), self.cversion, tostring(self.stale))
    return self.stale
end


--- Join a bridge channel.
-- @return True if connection success, false otherwise.
function GwChannel:join()


    if not self:is_configured() then

        -- Only join if we have the channel details
        return false

    elseif self.fdelay:hold() then

        -- Hold down in effect.
        return false

    elseif self:is_connected() then

        -- Already connected
        return true

    else

        gw.Debug(GW_LOG_INFO, 'joining channel; channel=%s, password=%s',
                gw.Redact(self.name), gw.Redact(self.password))
        JoinTemporaryChannel(self.name, self.password)
        local number = GetChannelName(self.name)

        if number == 0 then

            gw.Error('cannot create communication channel: %s', gw.Redact(self.name))
            self.stats.fconn = self.stats.fconn + 1
            self.fdelay:continue()
            return false

        else

            self.number = number
            self.stats.sconn = self.stats.sconn + 1
            self.fdelay:clear()
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

            -- Gratuitous officer announcement, veracity of the claim should be verified by the receiver.
            if gw.IsOfficer() then
                gw.SendLocal(GW_MTYPE_RESPONSE, 'officer')
            end

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

Informational Methods

--]]-----------------------------------------------------------------------

--- Dump the channel status.
-- @param label An identifier for the channel.
function GwChannel:dump_status(label)
    label = label or 'channel'
    gw.Write('%s: connected=%s, number=%d, channel=%s, password=%s, stale=%s (sconn=%d, fconn=%d, leave=%d, disco=%d)',
                label, tostring(self:is_connected()), self.number, gw.Redact(self.name),
                gw.Redact(self.password), tostring(self:is_stale()),
                self.stats.sconn, self.stats.fconn, self.stats.leave, self.stats.disco)
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
--     GW_MTYPE_EXTERNAL
-- @param ... Text of the message.
function GwChannel:send(type, ...)
    -- Apply adaptation layer encoding
    local message = self:al_encode(type, ...)
    if not message:match('%S') then
        gw.Debug(GW_LOG_WARNING, 'sending a blank message on channel %d', self.number)
    end
    gw.Debug(GW_LOG_NOTICE, 'channel=%d, type=%d, message=%q', self.number, type, message)
    return self:tl_send(type, message)
end

function GwChannel:al_encode(type, ...)
    local arg = {...}
    if type == GW_MTYPE_BROADCAST then
        assert(#arg >= 1)
        assert(#arg <= 3)
        return strjoin(':', arg[1], arg[2] or '', arg[3] or '')
    elseif type == GW_MTYPE_EXTERNAL then
        assert(#arg == 2)
        return strjoin(':', arg[1], base64.encode(arg[2]))
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
    elseif type == GW_MTYPE_LOOT then
        opcode = 'L'
    elseif type == GW_MTYPE_BROADCAST then
        opcode = 'B'
    elseif type == GW_MTYPE_NOTICE then
        opcode = 'N'
    elseif type == GW_MTYPE_REQUEST then
        opcode = 'R'
    elseif type == GW_MTYPE_ADDON then
        opcode = 'M'
    elseif type == GW_MTYPE_EXTERNAL then
        opcode = 'E'
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
    gw.Debug(GW_LOG_DEBUG, 'enqueued segment: %q', segment)
    return #self.tx_queue
end

--- Remove a segment from the channel transmit queue.
-- @return Segment removed from the queue or nil if queue is empty.
function GwChannel:tl_dequeue()
    local segment = tremove(self.tx_queue, 1)
    if segment then
        gw.Debug(GW_LOG_DEBUG, 'dequeued segment: %q', segment)
    end
    return segment
end

--- Transmit all messages in the channel transmit queue.
-- @return Number of messages flushed.
function GwChannel:tl_flush()
    gw.Debug(GW_LOG_DEBUG, 'servicing transmit queue; channel=%d, %d message(s) queued.', self.number, #self.tx_queue)
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
                gw.Debug(GW_LOG_INFO, 'channel=%d, segment=%q', self.number, segment)
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
    local sender, guild_id, mtype, message = self:tl_receive(...)
    sender = gw.GlobalName(sender)
    if message ~= nil then
        local content = self:al_decode(mtype, message)
        if mtype == GW_MTYPE_EXTERNAL then
            -- API traffic is handled regardless of the sender.
            if content ~= nil then
                local addon, api_message = unpack(content)
                if addon ~= nil and api_message ~= nil then
                    gw.APIDispatcher(addon, sender, guild_id, api_message)
                end
            end
        elseif sender ~= gw.player and guild_id ~= gw.config.guild_id then
            -- Process the chat message if it from another co-guild.
            gw.Debug(GW_LOG_NOTICE, 'channel=%d, type=%d, sender=%s, guild=%s, message=%q',
                    self.number, mtype, sender, guild_id, message)
            return f(mtype, guild_id, content, {...})
        end
    end
end

--- Adaptation layer decoding.
-- @param mtype message type
-- @param message message content
-- @return A table of message strings. Returns nil on error.
function GwChannel:al_decode(mtype, message)
    local function expand(message, n)
        assert(type(n) == 'number' and n > 0)
        message = type(message) == 'string' and message or ''
        local t = { strsplit(':', message, n) }
        for i = 1, n do
            t[i] = t[i] ~= nil and t[i] or ''
        end
        return t
    end

    gw.Debug(GW_LOG_DEBUG, 'type=%d, message=%q', mtype, message)
    if mtype == GW_MTYPE_BROADCAST then
        return expand(message, 3)
    elseif mtype == GW_MTYPE_EXTERNAL then
        local tag, data = unpack(expand(message, 2))
        local rv, result = pcall(base64.decode, data)
        if (rv) then
            return { tag, result }
        else
            gw.Debug(GW_LOG_DEBUG, 'API error: %s', result)
            return
        end
    else
        return { message }
    end
end

function GwChannel:tl_receive(...)
    local segment, sender = select(1, ...)
    sender = gw.GlobalName(sender)
    gw.Debug(GW_LOG_INFO, 'channel=%d, sender=%s, segment=%q', self.number, sender, segment)
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
    guild_id = guild_id or '-'
    message = message or ''
    gw.Debug(GW_LOG_DEBUG, 'opcode=%s, guild_id=%s, message=%q', opcode, guild_id, message)

    local type = GW_MTYPE_NONE
    if opcode == 'C' then
        type = GW_MTYPE_CHAT
    elseif opcode == 'A' then
        type = GW_MTYPE_ACHIEVEMENT
    elseif opcode == 'L' then
        type = GW_MTYPE_LOOT
    elseif opcode == 'B' then
        type = GW_MTYPE_BROADCAST
    elseif opcode == 'N' then
        type = GW_MTYPE_NOTICE
    elseif opcode == 'R' then
        type = GW_MTYPE_REQUEST
    elseif opcode == 'M' then
        type = GW_MTYPE_ADDON
    elseif opcode == 'E' then
        type = GW_MTYPE_EXTERNAL
    else
        gw.Debug(GW_LOG_ERROR, 'unknown segment opcode: %s', opcode)
    end
    return sender, guild_id, type, message
end

