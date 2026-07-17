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
            if gw.settings:get('roster') then
                gw.ReplicateMessage('SYSTEM', format(ERR_GUILD_REMOVE_SS, target, sender), guild_id, arglist)
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
        if i ~= 2 then
            -- skip combat log
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


