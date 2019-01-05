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

--]] -----------------------------------------------------------------------

local semver = LibStub:GetLibrary("SemanticVersion-1.0")


--- Callback handler for guild chat messages.
-- @param type Message type received.
-- @param guild_id ID of the guild the message was received from.
-- @param content Message content as a table.
-- @param arglist API event arguments.
function gw.handlerGuildChat(type, guild_id, content, arglist)
    gw.Debug(GW_LOG_DEBUG, 'type=%d, guild_id=%s, #content=%d, #arglist=%d', type, guild_id, #content, #arglist)
    local sender = arglist[2]
    if type == GW_MTYPE_CHAT then
        gw.ReplicateMessage('GUILD', content[1], guild_id, arglist)
    elseif type == GW_MTYPE_ACHIEVEMENT then
        if gw.settings:get('achievements') then
            gw.ReplicateMessage('GUILD_ACHIEVEMENT', content[1], guild_id, arglist)
        end
    elseif type == GW_MTYPE_LOOT then
        if gw.settings:get('achievements') then
            gw.ReplicateMessage('LOOT', content[1], guild_id, arglist)
        end
    elseif type == GW_MTYPE_BROADCAST then
        local action, target, rank = unpack(content)
        if action == 'join' then
            if gw.settings:get('roster') then
                gw.ReplicateMessage('SYSTEM', format(ERR_GUILD_JOIN_S, sender), guild_id, arglist)
            end
        elseif action == 'leave' then
            if gw.settings:get('roster') then
                gw.ReplicateMessage('SYSTEM', format(ERR_GUILD_LEAVE_S, sender), guild_id, arglist)
            end
        elseif action == 'remove' then
            if gw.settings:get('rank') then
                gw.ReplicateMessage('SYSTEM', format(ERR_GUILD_REMOVE_SS, target, sender), guild_id, arglist)
            end
        elseif action == 'promote' then
            if gw.settings:get('rank') then
                gw.ReplicateMessage('SYSTEM', format(ERR_GUILD_PROMOTE_SSS, sender, target, rank), guild_id, arglist)
            end
        elseif action == 'demote' then
            if gw.settings:get('rank') then
                gw.ReplicateMessage('SYSTEM', format(ERR_GUILD_DEMOTE_SSS, sender, target, rank), guild_id, arglist)
            end
        end
    else
        gw.Debug(GW_LOG_WARNING, 'unhandled message type: %d', type)
    end
end


--- Callback handler for officer chat messages.
-- @param type Message type received.
-- @param guild_id ID of the guild the mesage was received from.
-- @param content Message content as a table.
-- @param arglist API event arguments.
function gw.handlerOfficerChat(type, guild_id, content, arglist)
    gw.Debug(GW_LOG_DEBUG, 'type=%d, guild_id=%s, #content=%d, #arglist=%d', type, guild_id, #content, #arglist)
    if (type == GW_MTYPE_CHAT) then
        gw.ReplicateMessage('OFFICER', content[1], guild_id, arglist)
    else
        gw.Debug(GW_LOG_WARNING, 'unhandled message type: %d', type)
    end
end


--- Copies a message received on a common channel to all chat window instances of a
-- target chat channel.
-- @param event Chat message event to generate.
-- Accepted values:
-- 'GUILD'
-- 'OFFICER'
-- 'GUILD_ACHIEVEMENT'
-- 'LOOT'
-- 'SYSTEM'
-- @param message The message to replicate.
-- @param guild_id (optional) Guild ID of the sender.
-- @param arglist (optional) API event arguments.
function gw.ReplicateMessage(event, message, guild_id, arglist)
    guild_id = guild_id and guild_id or '-'
    arglist = type(arglist) == 'table' and arglist or {}
    local sender = arglist[2] and arglist[2] or ''
    local language = arglist[3]
    local target = arglist[5]
    local flags = arglist[6]
    local line = arglist[11]
    local guid = arglist[12]

    gw.Debug(GW_LOG_INFO, 'event=%s, guild_id=%s, message=%q', event, guild_id, message)

    if gw.settings:get('tag') and event ~= 'SYSTEM' then
        message = format('<%s> %s', guild_id, message)
    end

    local i
    for i = 1, NUM_CHAT_WINDOWS do
        if i ~= 2 then -- skip combat log
            gw.frame_table = { GetChatWindowMessages(i) }
            local v
            for _, v in ipairs(gw.frame_table) do
                if v == event then
                    local frame = 'ChatFrame' .. i
                    if _G[frame] then
                        gw.Debug(GW_LOG_DEBUG, 'frame=%s, event=%s, sender=%s, message=%q',
                            frame, event, sender, message)
                        gw.ChatFrame_MessageEventHandler(_G[frame], 'CHAT_MSG_' .. event, message,
                            sender, language, '', target, flags, 0, 0, '', 0, line, guid)
                    end
                    break
                end
            end
        end
    end
end


--- Sends an encoded message to the rest of the same container on the add-on channel.
-- @param type The message type: GW_MTYPE_CONTROL, GW_MTYPE_REQUEST, or GW_MTYPE_RESPONSE.
-- @param message Text of the message.
function gw.SendLocal(type, message)

    gw.Debug(GW_LOG_INFO, 'type=%s, message=%q', type, message)

    local opcode
    if type == nil then
        gw.Debug(GW_LOG_ERROR, 'cont_msg: missing arguments.')
        return
    elseif type == GW_MTYPE_CONTROL then
        opcode = 'I'
    elseif type == GW_MTYPE_REQUEST then
        opcode = 'C'
    elseif type == GW_MTYPE_RESPONSE then
        opcode = 'R'
    else
        gw.Debug(GW_LOG_ERROR, 'unknown message type: %s', type)
        return
    end

    local payload = strsub(strjoin('#', opcode, message), 1, 255)
    gw.Debug(GW_LOG_DEBUG, 'message=%q', payload)
    C_ChatInfo.SendAddonMessage('GreenWall', payload, 'GUILD')
end

--- Parses and handles an encoded message from the add-on channel.
-- @param sender The sender of the message.
-- @param message The encoded message.
-- @return True on successful handling, false on failure.
function gw.ReceiveLocal(sender, message)

    gw.Debug(GW_LOG_INFO, 'sender=%s, message=%q', sender, message)

    if not gw.iCmp(gw.GlobalName(sender), gw.player) then

        local opcode, payload = strsplit('#', message)
        payload = payload or ''
        gw.Debug(GW_LOG_DEBUG, 'opcode=%s, payload=%s', opcode, payload)

        if opcode == 'I' then

            if message == 'reload' then
                if gw.IsOfficer(sender) then
                    if gw.config.timer.reload:hold() then
                        gw.Write('Received configuration reload request from %s; hold-down in effect, skipping.', sender)
                    else
                        gw.Write('Received configuration reload request from %s.', sender)
                        gw.config:reload()
                        gw.config.timer.reload:start()
                    end
                end
            end

        elseif opcode == 'C' then

            if message == 'officer' then
                -- A query for officers
                if gw.IsOfficer() then
                    gw.SendLocal(GW_MTYPE_RESPONSE, 'officer')
                end
            end

        elseif opcode == 'R' then

            if message == 'officer' then
                -- A response to the officer query
                if gw.IsOfficer(sender) then
                    if gw.IsOfficer() then
                        gw.Debug(GW_LOG_NOTICE, 'giving %s moderator status', sender)
                        ChannelModerator(gw.config.channel.guild.name, sender)
                    else
                        gw.Debug(GW_LOG_NOTICE, 'giving %s owner status', sender)
                        SetChannelOwner(gw.config.channel.guild.name, sender)
                        ChannelUnmoderator(gw.config.channel.guild.name, gw.player)
                    end
                else
                    gw.Debug(GW_LOG_WARNING, 'officer spoofing attempt from %s', sender)
                end
            end
        end
    end

    return true
end

