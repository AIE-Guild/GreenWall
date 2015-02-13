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

--- Callback handler for guild chat messages.
-- @param type Message type received.
-- @param guild_id ID of the guild the mesage was received from.
-- @param content Message content as a table.
-- @param arglist API event arguments.
function gw.handlerGuildChat(type, guild_id, content, arglist)
    gw.Debug(GW_LOG_DEBUG, 'type=%d, guild_id=%s, #content=%d, #arglist=%d', type, guild_id, #content, #arglist)
    local sender = arglist[2]
    if type == GW_MTYPE_CHAT then
        gw.ReplicateMessage('GUILD', guild_id, content[1], arglist)
    elseif type == GW_MTYPE_ACHIEVEMENT then
        gw.ReplicateMessage('GUILD_ACHIEVEMENT', guild_id, content[1], arglist)
    elseif type == GW_MTYPE_BROADCAST then
        local action, target, rank = unpack(content)
        if action == 'join' then
            if GreenWall.roster then
                gw.ReplicateMessage('SYSTEM', guild_id, 
                        format(ERR_GUILD_JOIN_S, sender), arglist)
            end
        elseif action == 'leave' then
            if GreenWall.roster then
                gw.ReplicateMessage('SYSTEM', guild_id, 
                        format(ERR_GUILD_LEAVE_S, sender), arglist)
            end
        elseif action == 'remove' then
            if GreenWall.rank then
                gw.ReplicateMessage('SYSTEM', guild_id, 
                        format(ERR_GUILD_REMOVE_SS, target, sender), arglist)
            end
        elseif action == 'promote' then
            if GreenWall.rank then
                gw.ReplicateMessage('SYSTEM', guild_id, 
                        format(ERR_GUILD_PROMOTE_SSS, sender, target, rank), arglist)
            end
        elseif action == 'demote' then
            if GreenWall.rank then
                gw.ReplicateMessage('SYSTEM', guild_id, 
                        format(ERR_GUILD_DEMOTE_SSS, sender, target, rank), arglist)
            end
        end
    elseif type == GW_MTYPE_REQUEST then
        gw.Write('Received configuration reload request from %s.', sender)
        gw.config:reload()                              
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
        gw.ReplicateMessage('OFFICER', guild_id, content[1], arglist)
    else
        gw.Debug(GW_LOG_WARNING, 'unhandled message type: %d', type)
    end
end


--- Copies a message received on a common channel to all chat window instances of a 
-- target chat channel.
-- @param event Chat message event to generate.
--   Accepted values:
--     'CHAT_MSG_GUILD'
--     'CHAT_MSG_OFFICER'
--     'CHAT_MSG_GUILD_ACHIEVEMENT'
--     'CHAT_MSG_SYSTEM'
-- @param guild_id Guild ID of the sender.
-- @param message The message to replicate.
-- @param arglist API event arguments.
function gw.ReplicateMessage(event, guild_id, message, arglist)
    local sender = arglist[2]
    local language = arglist[3]
    local target = arglist[5]
    local flags = arglist[6]
    local guid = arglist[12]
    
    if GreenWall.tag then
        message = format('<%s> %s', guild_id, message)
    end
    
    local i    
    for i = 1, NUM_CHAT_WINDOWS do

        gw.frame_table = { GetChatWindowMessages(i) }
        
        local v
        for _, v in ipairs(gw.frame_table) do
                        
            if v == event then
                    
                local frame = 'ChatFrame' .. i
                if _G[frame] then
                    gw.Debug(GW_LOG_DEBUG, 'frame=%s, event=%s, sender=%s, message=%s', frame, event, sender, message)
                    ChatFrame_MessageEventHandler(_G[frame], 'CHAT_MSG_' .. event, message, sender, language, '', target, flags, 0, 0, '', 0, 0, guid)
                end
                break
                        
            end
                        
        end
                    
    end
    
end

