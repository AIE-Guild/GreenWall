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

--[[-----------------------------------------------------------------------

Imported Libraries

--]]-----------------------------------------------------------------------

local crc = LibStub:GetLibrary("Hash:CRC:16ccitt-1.0")
local b32h = LibStub:GetLibrary("Encoding:Base32Hex-1.0")


--[[-----------------------------------------------------------------------

Class Variables

--]]-----------------------------------------------------------------------

GwChannel = {}
GwChannel.__index = GwChannel
GwChannel.ChatWindowTable = {}

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

--- Join a bridge channel.
-- @return True if connection success, false otherwise.
function GwChannel:join()

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
        gw.Debug(GW_LOG_INFO, 'chan_join: name=<<%04X>>, number=%d', crc.Hash(self.name), self.number)
        gw.Write('Connected to confederation on channel %d.', self.number)
              
        --
        -- Hide the channel
        --
        for i = 1, 10 do
            GwChannel.ChatWindowTable = { GetChatWindowMessages(i) }
            for j, v in ipairs(GwChannel.ChatWindowTable) do
                if v == self.name then
                    local frame = format('ChatFrame%d', i)
                    if _G[frame] then
                        gw.Debug(GW_LOG_INFO, 'chan_join: hiding channel: name=<<%04X>>, number=%d, frame=%s', 
                                crc.Hash(self.name), self.number, frame)
                        ChatFrame_RemoveChannel(frame, self.name)
                    end
                end
            end
        end

        return true

    end

    return false

end

--- Leave a bridge channel.
function GwChannel:leave()
    if self:isConnected() then
        gw.Debug(GW_LOG_INFO, 'chan_leave: name=<<%04X>>, number=%d', crc.Hash(self.name), self.number)
        LeaveChannelByName(self.name)
        self.stats.leave = self.stats.leave + 1
        self.number = 0
        self.dirty = false
    end
end

--- Check if a connection exists to the custom channel.
-- @return True if connected, otherwise false.
function GwChannel:isConnected()
    if self.name then
        local number = GetChannelName(self.name)
        gw.Debug(GW_LOG_DEBUG, 'conn_check: chan_name=<<%04X>>, chan_id=%d',
                crc.Hash(self.name), number)
        if number ~= 0 then
            self.number = number
            return true
        end
    end
    return false            
end

--- Find channel roles for a player.
-- @param player Name of the player to check.
-- @return True if target is the channel owner, false otherwise.
-- @return True if target is a channel moderator, false otherwise.
function GwChannel:getRoles(player)
    assert(player ~= nil)
    if self.number ~= 0 then
        local _, _, _, _, count = GetChannelDisplayInfo(self.number)
        for i = 1, count do
            local target, town, tmod = GetChannelRosterInfo(self.number, i)
            if target == player then
                return town, tmod
            end
        end
    end
    return
end

--- Sends an encoded message on the shared channel.
-- @param message Text of the message.
-- @param type (optional) The message type.
-- Accepted values are: GW_CTYPE_CHAT, GW_CTYPE_ACHIEVEMENT, GW_CTYPE_BROADCAST, GW_CTYPE_NOTICE, GW_CTYPE_REQUEST, GW_CTYPE_ADDON.
-- Default is GW_CTYPE_CHAT.
function GwChannel:send(message, type)

    if type == nil then
        type = GW_CTYPE_CHAT
    end

    gw.Debug(GW_LOG_DEBUG, 'coguild_msg: type=%d, message=%s', type, message)

    if not self:isConnected() then
        gw.Debug(GW_LOG_ERROR, 'coguild_msg: not connected to channel', type)
        return
    end

    local opcode
    if type == GW_CTYPE_CHAT then
        opcode = 'C'
    elseif type == GW_CTYPE_ACHIEVEMENT then
        opcode = 'A'
    elseif type == GW_CTYPE_BROADCAST then
        opcode = 'B'
    elseif type == GW_CTYPE_NOTICE then
        opcode = 'N'
    elseif type == GW_CTYPE_REQUEST then
        opcode = 'R'
    elseif type == GW_CTYPE_ADDON then
        opcode = 'M'
    else
        gw.Debug(GW_LOG_WARNING, 'coguild_msg: unknown message type: %d', type)
        return
    end
    
    local coguild
    if gwContainerId == nil then
        gw.Debug(GW_LOG_NOTICE, 'coguild_msg: missing container ID.')
        coguild = '-'
    else
        coguild = gwContainerId
    end
    
    if message == nil then
        message = ''
    end
    
    -- Segment the message
    local n = GW_MAX_MESSAGE_LENGTH - (strlen(coguild) + 5)
    local buffer = message
    local segment = {}
    while strlen(buffer) > 0 do
        tinsert(segment, strsub(buffer, 1, n))
        buffer = strsub(buffer, n)
    end
    gw.Debug(GW_LOG_DEBUG, 'coguild_msg: %d segment(s)', #segment)
        
    
    -- Send the message.
    local flags = 0
    for i = 1, #segment do
        -- Set the EOM flag
        if i == #segment then
            flags = bit.band(flags, GW_MSG_END)
        end
        
        -- Format the message segment
        local payload = strsub(strjoin('#', opcode, coguild, b32h.Encode(flags), segment[i]), 1, GW_MAX_MESSAGE_LENGTH)
        gw.Debug(GW_LOG_DEBUG, 'Tx<%d, %s>: %s', self.number, gwPlayerName, payload)
        SendChatMessage(payload , 'CHANNEL', nil, self.number)

        -- Record the hash of the outbound segment for integrity checking, keeping a count of collisions.  
        local hash = crc.Hash(payload)
        if self.tx_hash[hash] == nil then
            self.tx_hash[hash] = 1
        else
            self.tx_hash[hash] = self.tx_hash[hash] + 1
        end

    end

end
