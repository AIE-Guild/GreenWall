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


--[[-----------------------------------------------------------------------

Global Variables

--]]-----------------------------------------------------------------------

--
-- Add-on metadata
--

gw = {}

--
-- Kludge to avoid the MoP glyph bug
--
local _

local gwVersion = GetAddOnMetadata('GreenWall', 'Version')

--
-- Default configuration values
--
local gwDefaults = {
    tag             = { default=true,   desc="co-guild tagging" },
    achievements    = { default=false,  desc="co-guild achievement announcements" },
    roster          = { default=true,   desc="co-guild roster announcements" },
    rank            = { default=false,  desc="co-guild rank announcements" },
    debug           = { default=GW_LOG_NONE, desc="debugging level" },
    verbose         = { default=false,  desc="verbose debugging" },
    log             = { default=false,  desc="event logging" },
    logsize         = { default=2048,   desc="maximum log buffer size" },
    ochat           = { default=false,  desc="officer chat bridging" },
}

local gwUsage = [[
 
  Usage:
  
  /greenwall <command>  or  /gw <command>
  
  Commands:
  
  help 
        -- Print this message.
  version
        -- Print the add-on version.
  status
        -- Print configuration and state information.
  stats
        -- Print connection statistics.
  refresh
        -- Repair communications link.
  achievements <on|off>
        -- Toggle display of confederation achievements.
  roster <on|off>
        -- Toggle display of confederation online, offline, join, and leave messages.
  rank <on|off>
        -- Toggle display of confederation promotion and demotion messages.
  tag <on|off>
        -- Show co-guild identifier in messages.
  ochat <on|off>
        -- Enable officer chat bridging.
  debug <level>
        -- Set debugging level to integer <level>.
  verbose <on|off>
        -- Toggle the display of debugging output in the chat window.
  log <on|off>
        -- Toggle output logging to the GreenWall.lua file.
  logsize <length>
        -- Specify the maximum number of log entries to keep.
 
]]
        
--
-- Player variables
--

local gwRealmName       = GetRealmName()
local gwPlayerName      = UnitName('player') .. '-' .. gwRealmName:gsub("%s+", "")
local gwGuildName       = nil  -- wait until guild info is retrieved. 
local gwPlayerLanguage  = GetDefaultLanguage('Player')


--
-- Co-guild variables
--

local gwConfederation   = ""
local gwContainerId     = nil
local gwPeerTable       = {}
local gwCommonChannel 	= {}
local gwOfficerChannel 	= {}


--
-- State variables
--

local gwAddonLoaded     = false
local gwFlagChatBlock   = true
local gwStateSendWho    = 0


--
-- Cache tables
--

local gwComemberCache   = {}
local gwComemberTimeout = 180


--
-- Guild options
--
local gwOptMinVersion   = gwVersion
local gwOptChanKick     = false
local gwOptChanBan      = false


--
-- Timers and thresholds
--

-- Timeout for General chat barrier
local gwChatBlockTimeout    = 30
local gwChatBlockTimestamp  = 0

-- Configuration hold-down
local gwConfigHoldInt   = 300
local gwConfigHoldTime  = 0

-- Hold-down for reload requests
local gwReloadHoldInt   = 180
local gwReloadHoldTime  = 0

-- Channel ownership handoff
local gwHandoffTimeout  = 15
local gwHandoffTimer    = nil


--
-- Tables external to functions
--

local gwChannelTable    = {}
local gwChatWindowTable = {}
local gwFrameTable      = {}
local gwGuildCheck      = {}


--[[-----------------------------------------------------------------------

Convenience Functions

--]]-----------------------------------------------------------------------

--- Case insensitive string comparison.
-- @param a A string
-- @param b A string
-- @return True if the strings match in all respects except case, false otherwise.
local function GwCmp(a, b)
    if string.lower(a) == string.lower(b) then
        return true
    else
        return false
    end
end


--- Format name for cross-realm addressing.
-- @param name Character name or guild name.
-- @param realm Name of the realm.
-- @return A formatted cross-realm address.
local function GwGlobalName(name, realm)

    -- Pass formatted names without modification.
    if name:match(".+-[%a']+$") then
        return name
    end

    -- Use local realm as the default.
    if realm == nil then
        realm = gwRealmName
    end

    return name .. '-' .. realm:gsub("%s+", "")

end


--- Get the player's fully-qualified guild name.
-- @param target (optional) unit ID, default is 'Player'.
-- @return A qualified guild name or nil if the player is not in a guild.
local function GwGuildName(target)
    if target == nil then
        target = 'Player'
    end
    local name, _, _, realm = GetGuildInfo(target)
    if name == nil then
        return
    end
    return GwGlobalName(name, realm)
end


--- Check if a connection exists to the common chat.
-- @param chan A channel control table.
-- @return True if connected, otherwise false.
local function GwIsConnected(chan)

    if chan.name then
        chan.number = GetChannelName(chan.name)
        gw.Debug(GW_LOG_DEBUG, 'conn_check: chan_name=<<%04X>>, chan_id=%d', crc.Hash(chan.name), chan.number)
        if chan.number ~= 0 then
            return true
        end
    end
    
    return false
            
end


--- Check a target player for officer status in the same container guild.
-- @param target The name of the player to check.
-- @return True is the target has at least read access to officer chat and officer notes, false otherwise.
local function GwIsOfficer(target)

    local rank;
    local see_chat = false
    local see_note = false
    
    if target == nil then
        target = 'Player'
    end
    _, _, rank = GetGuildInfo(target)
    
    if rank == 0 then
        see_chat = true
        see_note = true
    else
        GuildControlSetRank(rank);
        for i, v in ipairs({GuildControlGetRankFlags()}) do
            local flag = _G["GUILDCONTROL_OPTION"..i]
            if flag == 'Officerchat Listen' then
                see_chat = true
            elseif flag == 'View Officer Note' then
                see_note = true
            end
        end
    end
    
    local result = see_chat and see_note
    gw.Debug(GW_LOG_INFO, 'is_officer: %s; rank=%d, chat=%s, note=%s', 
            tostring(result), rank, tostring(see_chat), tostring(see_note));

    return result;

end


--- Create a new channel control data structure.
-- @param name The channel name.
-- @param password The channel password.
-- @return Channel control table.
local function GwNewChannelTable(name, password)
    local tab = {
        name = name,
        password = password,
        number = 0,
        configured = false,
        dirty = false,
        owner = false,
        handoff = false,
        queue = {},
        tx_hash = {},
        stats = {
            sconn = 0,
            fconn = 0,
            leave = 0,
            disco = 0
        }
    }
    return tab
end


--- Check a guild for peer status.
-- @param guild The name of the guild to check.
-- @return True if the target guild is a peer co-guild, false otherwise.
local function GwIsPeer(guild)
    for i, v in pairs(gwPeerTable) do
        if v == guild then
            return true
        end
    end
    return false
end


--- Check a guild for membership within the confederation.
-- @param guild The name of the guild to check.
-- @return True if the target guild is in the confederation, false otherwise.
local function GwIsContainer(guild)
    if guild == gwGuildName then
        return gwContainerId ~= nil
    else
        return GwIsPeer(guild)
    end
end


--- Finds channel roles for a player.
-- @param chan Control table for the channel.
-- @param name Name of the player to check.
-- @return True if target is the channel owner, false otherwise.
-- @return True if target is a channel moderator, false otherwise.
local function GwChannelRoles(chan, name)
        
    if name == nil then
        name = gwPlayerName
    end
    
    if chan.number ~= 0 then
        local _, _, _, _, count = GetChannelDisplayInfo(chan.number)
        for i = 1, count do
            local target, town, tmod = GetChannelRosterInfo(chan.number, i)
            if GwCmp(target, name) then
                return town, tmod
            end
        end
    end
    
    return
    
end


--- Copies a message received on the common channel to all chat window instances of a 
-- target chat channel.
-- @param target Target channel type.
-- @param sender The sender of the message.
-- @param container Container ID of the sender.
-- @param language The language used for the message.
-- @param flags Status flags for the message sender.
-- @param message Text of the message.
-- @param counter System message counter.
-- @param guid GUID for the sender.
local function GwReplicateMessage(target, sender, container, language, flags,
        message, counter, guid)
    
    local event
    if target == 'GUILD' then
        event = 'CHAT_MSG_GUILD'
    elseif target == 'OFFICER' then
        event = 'CHAT_MSG_OFFICER'
    elseif target == 'GUILD_ACHIEVEMENT' then
        event = 'CHAT_MSG_GUILD_ACHIEVEMENT'
    elseif target == 'SYSTEM' then
        event = 'CHAT_MSG_SYSTEM'
    else
        gw.Error('invalid target channel: ' .. target)
        return
    end
    
    if sender == nil then
        sender = '*'
    end
    
    if GreenWall.tag and container ~= nil then
        message = format('<%s> %s', container, message)
    end
    
    local i    
    for i = 1, NUM_CHAT_WINDOWS do

        gwFrameTable = { GetChatWindowMessages(i) }
        
        local v
        for _, v in ipairs(gwFrameTable) do
                        
            if v == target then
                    
                local frame = 'ChatFrame' .. i
                if _G[frame] then
                    gw.Debug(GW_LOG_DEBUG, 'Cp<%s/%s, *, %s>: %s', frame, target, sender, message)
                    
                    ChatFrame_MessageEventHandler(
                            _G[frame], 
                            event, 
                            message, 
                            sender, 
                            language, 
                            '', 
                            '', 
                            '', 
                            0, 
                            0, 
                            '', 
                            0, 
                            0, 
                            guid
                        )
                end
                break
                        
            end
                        
        end
                    
    end
    
end


--- Sends an encoded message to the rest of the confederation on the shared channel.
-- @param chan The channel control table.
-- @param type The message type.
-- Accepted values are: chat, achievement, broadcast, notice, and request.
-- @param message Text of the message.
-- @param sync (optional) Boolean specifying whether to suppress queuing of messages.  Default is false. 
local function GwSendConfederationMsg(chan, type, message, sync)

    if sync == nil then
        sync = false
        gw.Debug(GW_LOG_DEBUG, 'coguild_msg: type=%s, async, message=%s', type, message)
    else
        gw.Debug(GW_LOG_DEBUG, 'coguild_msg: type=%s, sync, message=%s', type, message)
    end

    -- queue messages id not connected
    if not GwIsConnected(chan) then
        if not sync then 
            tinsert(chan.queue, { type, message })
            gw.Debug(GW_LOG_DEBUG, 'coguild_msg: queued %s message: %s', type, message)
        end
        return
    end

    local opcode
    if type == nil then
        gw.Debug(GW_LOG_DEBUG, 'coguild_msg: missing arguments.')
        return
    elseif type == 'chat' then
        opcode = 'C'
    elseif type == 'achievement' then
        opcode = 'A'
    elseif type == 'broadcast' then
        opcode = 'B'
    elseif type == 'notice' then
        opcode = 'N'
    elseif type == 'request' then
        opcode = 'R'
    elseif type == 'addon' then
        opcode = 'M'
    else
        gw.Debug(GW_LOG_WARNING, 'coguild_msg: unknown message type: %s', type)
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
    
    -- Format the message.
    local payload = strsub(strjoin('#', opcode, coguild, '', message), 1, 255)
    
    -- Send the message.
    gw.Debug(GW_LOG_DEBUG, 'Tx<%d, %s>: %s', chan.number, gwPlayerName, payload)
    SendChatMessage(payload , "CHANNEL", nil, chan.number)

    -- Record the hash of the outbound message for integrity checking, keeping a count of collisions.  
    local hash = crc.Hash(payload)
    if chan.tx_hash[hash] == nil then
        chan.tx_hash[hash] = 1
    else
        chan.tx_hash[hash] = chan.tx_hash[hash] + 1
    end

end


--- Sends an encoded message to the rest of the same container on the add-on channel.
-- @param type The message type.
-- @field request Command request.
-- @field response Command response.
-- @field info Informational message.
-- @param message Text of the message.
local function GwSendContainerMsg(type, message)

    gw.Debug(GW_LOG_DEBUG, 'cont_msg: type=%s, message=%s', type, message)

    local opcode
    
    if type == nil then
        gw.Debug(GW_LOG_ERROR, 'cont_msg: missing arguments.')
        return
    elseif type == 'request' then
        opcode = 'C'
    elseif type == 'response' then
        opcode = 'R'
    elseif type == 'info' then
        opcode = 'I'
    else
        gw.Debug(GW_LOG_ERROR, 'cont_msg: unknown message type: %s', type)
        return
    end

    local payload = strsub(strjoin('#', opcode, message), 1, 255)
    gw.Debug(GW_LOG_DEBUG, 'Tx<ADDON/GUILD, *, %s>: %s', gwPlayerName, payload)
    SendAddonMessage('GreenWall', payload, 'GUILD')
    
end


--- Encode a broadcast message.
-- @param action The action type.
-- @param target The target of the action (optional).
-- @param arg Additional data (optional).
-- @return An encoded string.
local function GwEncodeBroadcast(action, target, arg)
    return strjoin(':', tostring(action), tostring(target), tostring(arg))
end


--- Decode a broadcast message.
-- @param string An encoded string.
-- @return The action type.
-- @return The target of the action (optional).
-- @return Additional data (optional).
local function GwDecodeBroadcast(string)
    local elem = { strsplit(':', string) }
    return elem[1], elem[2], elem[3]
end


--- Leave a shared confederation channel.
-- @param chan The channel control table.
local function GwLeaveChannel(chan)

    local id, name = GetChannelName(chan.number)
    if name then
        gw.Debug(GW_LOG_INFO, 'chan_leave: name=<<%04X>>, number=%d', crc.Hash(name), chan.number)
        LeaveChannelByName(name)
        chan.number = 0
        chan.stats.leave = chan.stats.leave + 1
    end

end


--- Leave a shared confederation channel and clear current configuration.
-- @param chan The channel control table.
local function GwAbandonChannel(chan)

    local id, name = GetChannelName(chan.number)
    if name then
        gw.Debug(GW_LOG_INFO, 'chan_abandon: name=<<%04X>>, number=%d', crc.Hash(name), chan.number)
        chan.name = ''
        chan.password = ''
        LeaveChannelByName(name)
        chan.number = 0
        chan.stats.leave = chan.stats.leave + 1
    end

end 

--- Join the shared confederation channel.
-- @param chan the channel control block.
-- @return True if connection success, false otherwise.
local function GwJoinChannel(chan)

    if chan.name then
        --
        -- Open the communication link
        --
        chan.number = GetChannelName(chan.name)
        if chan.number == 0 then
            JoinTemporaryChannel(chan.name, chan.password)
            chan.number = GetChannelName(chan.name)
        end
        
        if chan.number == 0 then

            gw.Error('cannot create communication channel: %s', chan.number)
            chan.stats.fconn = chan.stats.fconn + 1
            return false

        else
        
            gw.Debug(GW_LOG_INFO, 'chan_join: name=<<%04X>>, number=%d', crc.Hash(chan.name), chan.number)
            gw.Write('Connected to confederation on channel %d.', chan.number)
            
            chan.stats.sconn = chan.stats.sconn + 1
            
            --
            -- Check for default permissions
            --
            DisplayChannelOwner(chan.number)
            
            --
            -- Hide the channel
            --
            for i = 1, 10 do
                gwChatWindowTable = { GetChatWindowMessages(i) }
                for j, v in ipairs(gwChatWindowTable) do
                    if v == chan.name then
                        local frame = format('ChatFrame%d', i)
                        if _G[frame] then
                            gw.Debug(GW_LOG_INFO, 'chan_join: hiding channel: name=<<%04X>>, number=%d, frame=%s', 
                                    crc.Hash(chan.name), chan.number, frame)
                            ChatFrame_RemoveChannel(frame, chan.name)
                        end
                    end
                end
            end
            
            --
            -- Request permissions if necessary
            --
            if GwIsOfficer() then
                GwSendContainerMsg('response', 'officer')
            end
            
            return true
            
        end
        
    end

    return false

end


--- Drain a channel's message queue.
-- @param chan Channel control table.
-- @return Number of messages flushed.
local function GwFlushChannel(chan)
    gw.Debug(GW_LOG_DEBUG, 'chan_flush: draining channel queue: name=<<%04X>>, number=%d', 
            crc.Hash(chan.name), chan.number)
    count = 0
    while true do
        rec = tremove(chan.queue, 1)
        if rec == nil then
            break
        else
            GwSendConfederationMsg(chan, rec[1], rec[2], true)
            count = count + 1
        end
    end
    return count
end


--- Clear confederation configuration and request updated guild roster 
-- information from the server.
local function GwPrepComms()
    
    gw.Debug(GW_LOG_INFO, 'prep_comms: initiating reconnect, querying guild roster.')
    
    gwConfederation = ""
    gwContainerId   = nil
    gwPeerTable     = {}
    gwCommonChannel = GwNewChannelTable()
    gwOfficerChannel = GwNewChannelTable()

    GuildRoster()
    
end


--- Parse the confederation configuration information.
-- @param text Text containing the confederation configuration
-- @return A table containing the parsed configuration.
local function GwParseConfig(text)

    local config = {}
    local var    = {}
    local seen   = {}
    
    for op, buffer in gmatch(text, 'GW(%l)="([^"]*)"') do
        local args = { strsplit('|', buffer) }
        if seen[op] then
            gw.Error('ignored duplicate directive in configuration: GW%s', op)
        else
            seen[op] = true
            if op == "c" then
                config.conf_name    = args[1]
                config.cont_tag     = args[2]
                config.gchan_name   = args[3]
                config.gchan_pass   = args[4]
            elseif op == "e" then
                config.gchan_key    = args[1]
                config.gchan_cipher = args[2]
            elseif op == "a" then
                config.ochan_name   = args[1]
                config.ochan_pass   = args[2]
                config.ochan_key    = args[3]
                config.ochan_cipher = args[4]
            elseif op == "s" then
                if args[1] and args[2] then
                    var[args[1]] = args[2]
                end
            elseif op == "v" then
                config.min_ver      = args[1]
            else
                gw.Debug(GW_LOG_ERROR, 'unknown configuration directive: GW%s', op)
                seen[op] = nil
            end
        end
    end
    
    for op, buffer in gmatch(text, 'GW:?(%l):([^\n]*)') do
        local args = { strsplit(':', buffer) }
        if seen[op] then
            gw.Error('ignored duplicate directive in configuration: GW%s', op)
        else
            seen[op] = true
            if op == "c" then
                config.conf_name    = ""
                config.cont_tag     = ""
                config.gchan_name   = args[1]
                config.gchan_pass   = args[2]
            elseif op == "a" then
                config.ochan_name   = args[1]
                config.ochan_pass   = args[2]
            elseif op == "s" then
                if args[1] and args[2] then
                    var[args[2]] = args[1]
                end
            elseif op == "v" then
                config.min_ver      = args[1]
            elseif op == "d" then
                config.min_ver      = args[1]
            else
                gw.Debug(GW_LOG_ERROR, 'unknown configuration directive: GW%s', op)
                seen[op] = nil
            end
        end
    end
        
    return config
end


--- Parse the guild information page to gather configuration information.
-- @param chan Channel control table to update.
-- @return True if successful, false otherwise.
local function GwGetGuildInfoConfig(chan)

    gw.Debug(GW_LOG_INFO, 'guild_info: parsing guild information.')

    local info = GetGuildInfoText()     -- Guild information text.
    local xlat = {}                     -- Translation table for string substitution.
    
    if info == '' then

        gw.Debug(GW_LOG_INFO, 'guild_info: not yet available.')
        return false
    
    else    

        -- Make sure we know which co-guild we are in.
        if gwGuildName == nil or gwGuildName == '' then
            gwGuildName = GwGuildName()
            if gwGuildName == nil then
                gw.Debug(GW_LOG_ERROR, 'guild_info: co-guild unavailable.')
                return false
            else
                gw.Debug(GW_LOG_INFO, 'guild_info: co-guild is %s.', gwGuildName)
            end
        end
    
        -- We will rebuild the list of peer container guilds
        wipe(gwPeerTable)
        wipe(xlat)

        for buffer in gmatch(info, 'GW:?(%l:[^\n]*)') do
        
            if buffer ~= nil then
                        
                buffer = strtrim(buffer)
                local vector = { strsplit(':', buffer) }
            
                if vector[1] == 'c' then
                
                    -- Common Channel:
                    -- This specifies the custom chat channel to use for all general confederation bridging.
                    
                    if chan.name ~= vector[2] then
                        chan.name = vector[2]
                        chan.dirty = true
                    end
                    
                    if chan.password ~= vector[3] then
                        chan.password = vector[3]
                        chan.dirty = true
                    end
                        
                    gw.Debug(GW_LOG_DEBUG, 'guild_info: channel=<<%04X>>, password=<<%04X>>', 
                            crc.Hash(chan.name), crc.Hash(chan.password))

                elseif vector[1] == 'p' then
        
                    -- Peer Co-Guild:
                    -- You must specify one of these directives for each co-guild in the confederation, including the co-guild you are configuring.
                    
                    local cog_name, cog_id, count
                    
                    cog_name, count = string.gsub(vector[2], '%$(%a)', function(a) return xlat[a] end)
                    cog_name = GwGlobalName(cog_name)
                    if count > 0 then
                        gw.Debug(GW_LOG_INFO, 'guild_info: parser co-guild name substitution "%s" => "%s"', vector[2], cog_name)
                    end
                    
                    cog_id, count   = string.gsub(vector[3], '%$(%a)', function(a) return xlat[a] end)
                    if count > 0 then
                        gw.Debug(GW_LOG_INFO, 'guild_info: parser co-guild ID substitution "%s" => "%s"', vector[3], cog_id)
                    end
                    
                    if cog_name == gwGuildName then
                        gwContainerId = cog_id
                        gw.Debug(GW_LOG_INFO, 'guild_info: container=%s (%s)', gwGuildName, gwContainerId)
                    else 
                        gwPeerTable[cog_id] = cog_name
                        gw.Debug(GW_LOG_INFO, 'guild_info: peer=%s (%s)', cog_name, cog_id)
                    end
                    
                elseif vector[1] == 's' then
                
                    -- Substitution Variable:
                    -- This specifies a variable that will can be used in the peer co-guild directives to reduce the size of the configuration.
                           
                    local key = vector[3]
                    local val = vector[2]            
                    if string.len(key) == 1 then
                        if key ~= nil then
                            xlat[key] = val
                            gw.Debug(GW_LOG_INFO, 'guild_info: parser substitution rule added, "$%s" := "%s"', key, val)
                        end
                    else
                        gw.Debug(GW_LOG_ERROR, 'guild_info: invalid parser substitution variable name, "$%s"', key)
                    end
                                        
                elseif vector[1] == 'v' then
                
                    -- Minimum Version:
                    -- The minimum version of GreenWall that the guild management wishes to allow members to use.
                    
                    if strmatch(vector[2], '^%d+%.%d+%.%d+%w*$') then
                        gwOptMinVersion = vector[2]
                        gw.Debug(GW_LOG_INFO, 'guild_info: minimum version is %s', gwOptMinVersion)
                    end
                    
                elseif vector[1] == 'd' then
                
                    -- Channel Defense:
                    -- This option specifies the type of channel defense hat should be employed. This feature is currently unimplemented.
                    
                    if vector[2] == 'k' then
                        gwOptChanKick = true
                        gw.Debug(GW_LOG_INFO, 'guild_info: channel defense mode is kick.')
                    elseif vector[2] == 'kb' then
                        gwOptChanBan = true
                        gw.Debug(GW_LOG_INFO, 'guild_info: channel defense mode is kick/ban.')
                    else
                        gw.Debug(GW_LOG_INFO, 'guild_info: channel defense mode is disabled.')
                    end
                                                                     
                elseif vector[1] == 'o' then
                
                    -- Option List:
                    -- This is the old, deprecated format for specifying configuration options.
                
                    local optlist = { strsplit(',', gsub(vector[2], '%s+', '')) }
                
                    for i, opt in ipairs(optlist) do
                    
                        local k, v = strsplit('=', opt)
                    
                        k = strlower(k)
                        v = strlower(v)
                        
                        if k == 'mv' then
                            if strmatch(v, '^%d+%.%d+%.%d+%w*$') then
                                gwOptMinVersion = v
                                gw.Debug(GW_LOG_INFO, 'guild_info: minimum version is %s', gwOptMinVersion)
                            end
                        elseif k == 'cd' then
                            if v == 'k' then
                                gwOptChanKick = true
                                gw.Debug(GW_LOG_INFO, 'guild_info: channel defense mode is kick.')
                            elseif v == 'kb' then
                                gwOptChanBan = true
                                gw.Debug(GW_LOG_INFO, 'guild_info: channel defense mode is kick/ban.')
                            else
                                gw.Debug(GW_LOG_INFO, 'guild_info: channel defense mode is disabled.')
                            end
                        end
                        
                    end
                                    
                end
        
            end
    
        end
            
        chan.configured = true
        gw.Debug(GW_LOG_INFO, 'guild_info: configuration updated.')
            
    end
        
    return true
        
end


--- Parse the officer note of the guild leader to gather configuration information.
-- @param chan Channel control table to update.
-- @return True if successful, false otherwise.
local function GwGetOfficerNoteConfig(chan)

    -- Avoid pointless work if we're not an officer
    if not GwIsOfficer() then
        return false
    end
    
    -- Find the guild leader
    local n = GetNumGuildMembers()
    local leader = 0
    local config = ''

    local name
    local rank
    local note
    for i = 1, n do
        name, _, rank, _, _, _, _, note = GetGuildRosterInfo(i)
        if rank == 0 then
            gw.Debug(GW_LOG_INFO, 'officer_note: parsing officer note for %s.', name)
            leader = 1
            config = note
            break
        end
    end
    
    if leader == 0 then
        return false
    else

        -- update the channel control table
        chan.name, chan.password = config:match('GW:?a:([%w_]+):([%w_]*)')
        if chan.name ~= nil then
            chan.configured = true
            gw.Debug(GW_LOG_DEBUG, 
                    'officer_note: channel=<<%04X>>, password=<<%04X>>', 
                    crc.Hash(chan.name), crc.Hash(chan.password))
            return true
        else
            return false
        end        
    end
    
end


--- Parse confederation configuration and connect to the common channel.
local function GwRefreshComms()

    gw.Debug(GW_LOG_INFO, 'refresh_comms: refreshing communication channels.')

    --
    -- Connect if necessary
    --
    if GwIsConnected(gwCommonChannel) then    
        if gwCommonChannel.dirty then
            gw.Debug(GW_LOG_INFO, 'refresh_comms: common channel dirty flag set.')
            GwLeaveChannel(gwCommonChannel)
            if GwJoinChannel(gwCommonChannel) then
                GwFlushChannel(gwCommonChannel)
            end
            gwCommonChannel.dirty = false
        end
    elseif gwFlagChatBlock then
        gw.Debug(GW_LOG_INFO, 'refresh_comms: deferring common channel refresh, General not yet joined.')
    else    
        if GwJoinChannel(gwCommonChannel) then
            GwFlushChannel(gwCommonChannel)
        end
    end

    if GreenWall.ochat then
        if GwIsConnected(gwOfficerChannel) then    
            if gwOfficerChannel.dirty then
                gw.Debug(GW_LOG_INFO, 'refresh_comms: common channel dirty flag set.')
                GwLeaveChannel(gwOfficerChannel)
                if GwJoinChannel(gwOfficerChannel) then
                    GwFlushChannel(gwOfficerChannel)
                end
                gwOfficerChannel.dirty = false
            end
        elseif gwFlagChatBlock then
            gw.Debug(GW_LOG_INFO, 'refresh_comms: deferring officer channel refresh, General not yet joined.')
        else    
            if GwJoinChannel(gwOfficerChannel) then
                GwFlushChannel(gwOfficerChannel)
            end
        end
    end

end


--- Send a configuration reload request to the rest of the confederation.
local function GwForceReload()
    if GwIsConnected(gwCommonChannel) then
        GwSendConfederationMsg(gwCommonChannel, 'request', 'reload')
    end 
end


--[[-----------------------------------------------------------------------

UI Handlers

--]]-----------------------------------------------------------------------

function GreenWallInterfaceFrame_OnShow(self)
    if (not gwAddonLoaded) then
        -- Configuration not loaded.
        self:Hide()
        return
    end
    
    -- Populate interface panel.
    getglobal(self:GetName().."OptionTag"):SetChecked(GreenWall.tag)
    getglobal(self:GetName().."OptionAchievements"):SetChecked(GreenWall.achievements)
    getglobal(self:GetName().."OptionRoster"):SetChecked(GreenWall.roster)
    getglobal(self:GetName().."OptionRank"):SetChecked(GreenWall.rank)
    if (GwIsOfficer()) then
        getglobal(self:GetName().."OptionOfficerChat"):SetChecked(GreenWall.ochat)
        getglobal(self:GetName().."OptionOfficerChatText"):SetTextColor(1, 1, 1)
        getglobal(self:GetName().."OptionOfficerChat"):Enable()
    else
        getglobal(self:GetName().."OptionOfficerChat"):SetChecked(false)
        getglobal(self:GetName().."OptionOfficerChatText"):SetTextColor(.5, .5, .5)
        getglobal(self:GetName().."OptionOfficerChat"):Disable()
    end
end

function GreenWallInterfaceFrame_SaveUpdates(self)
    GreenWall.tag = getglobal(self:GetName().."OptionTag"):GetChecked() and true or false
    GreenWall.achievements = getglobal(self:GetName().."OptionAchievements"):GetChecked() and true or false
    GreenWall.roster = getglobal(self:GetName().."OptionRoster"):GetChecked() and true or false
    GreenWall.rank = getglobal(self:GetName().."OptionRank"):GetChecked() and true or false
    if (GwIsOfficer()) then
        GreenWall.ochat = getglobal(self:GetName().."OptionOfficerChat"):GetChecked() and true or false
    end    
end

function GreenWallInterfaceFrame_SetDefaults(self)
    GreenWall.tag = gwDefaults['tag']['default']
    GreenWall.achievements = gwDefaults['achievements']['default']
    GreenWall.roster = gwDefaults['roster']['default']
    GreenWall.rank = gwDefaults['rank']['default']
    GreenWall.ochat = gwDefaults['ochat']['default']
end


--[[-----------------------------------------------------------------------

Slash Command Handler

--]]-----------------------------------------------------------------------

--- Update or display the value of a user configuration variable.
-- @param key The name of the variable.
-- @param val The variable value.
-- @return True if the key matches a variable name, false otherwise.
local function GwCmdConfig(key, val)
    if key == nil then
        return false
    else
        if gwDefaults[key] ~= nil then
            local default = gwDefaults[key]['default']
            local desc = gwDefaults[key]['desc']
            if type(default) == 'boolean' then
                if val == nil or val == '' then
                    if GreenWall[key] then
                        gw.Write(desc .. ' turned ON.', desc)
                    else
                        gw.Write(desc .. ' turned OFF.')
                    end
                elseif val == 'on' then
                    GreenWall[key] = true
                    gw.Write(desc .. ' turned ON.')
                elseif val == 'off' then
                    GreenWall[key] = false
                    gw.Write(desc .. ' turned OFF.')
                else
                    gw.Error('invalid argument for %s: %s', desc, val)
                end
                return true
            elseif type(default) == 'number' then
                if val == nil or val == '' then
                    if GreenWall[key] then
                        gw.Write('%s set to %d.', desc, GreenWall[key])
                    end
                elseif val:match('^%d+$') then
                    GreenWall[key] = val + 0
                    gw.Write('%s set to %d.', desc, GreenWall[key])
                else
                    gw.Error('invalid argument for %s: %s', desc, val)
                end
                return true
            end
        end
    end
    return false
end


local function GwSlashCmd(message, editbox)

    --
    -- Parse the command
    --
    local command, argstr = message:match('^(%S*)%s*(%S*)%s*')
    command = command:lower()
    
    gw.Debug(GW_LOG_DEBUG, 'slash_cmd: command=%s, args=%s', command, argstr)
    
    if command == nil or command == '' or command == 'help' then
    
        for line in string.gmatch(gwUsage, '([^\n]*)\n') do
            gw.Write(line)
        end
    
    elseif GwCmdConfig(command, argstr) then
    
        -- Some special handling here
        if command == 'logsize' then
            while # GreenWallLog > GreenWall.logsize do
                tremove(GreenWallLog, 1)
            end
        elseif command == 'ochat' then
            GwGetOfficerNoteConfig(gwOfficerChannel)
            GwRefreshComms()
        end
    
    elseif command == 'reload' then
    
        GwForceReload()
        gw.Write('Broadcast configuration reload request.')
    
    elseif command == 'refresh' then
    
        GwRefreshComms()
        gw.Write('Refreshed communication link.')
    
    elseif command == 'status' then
    
        gw.Write('container=' .. tostring(gwContainerId))
        gw.Write('common: chan=<<%04X>>, num=%d, pass=<<%04X>>, connected=%s',
                crc.Hash(gwCommonChannel.name), 
                tostring(gwCommonChannel.number), 
                crc.Hash(gwCommonChannel.password),
                tostring(GwIsConnected(gwCommonChannel))
            )
        if GreenWall.ochat then
            gw.Write('officer: chan=<<%04X>>, num=%d, pass=<<%04X>>, connected=%s',
                    crc.Hash(gwOfficerChannel.name), 
                    tostring(gwOfficerChannel.number), 
                    crc.Hash(gwOfficerChannel.password),
                    tostring(GwIsConnected(gwOfficerChannel))
                )
        end
        
        gw.Write('hold_down=%d/%d', (time() - gwConfigHoldTime), gwConfigHoldInt)
        -- gw.Write('chan_kick=' .. tostring(gwOptKick))
        -- gw.Write('chan_ban=' .. tostring(gwOptBan))
        
        for i, v in pairs(gwPeerTable) do
            gw.Write('peer[%s] => %s', i, v)
        end
    
        gw.Write('version='      .. gwVersion)
        gw.Write('min_version='  .. gwOptMinVersion)
        
        gw.Write('tag='          .. tostring(GreenWall.tag))
        gw.Write('achievements=' .. tostring(GreenWall.achievements))
        gw.Write('roster='       .. tostring(GreenWall.roster))
        gw.Write('rank='         .. tostring(GreenWall.rank))
        gw.Write('debug='        .. tostring(GreenWall.debug))
        gw.Write('verbose='      .. tostring(GreenWall.verbose))
        gw.Write('log='          .. tostring(GreenWall.log))
        gw.Write('logsize='      .. tostring(GreenWall.logsize))
    
    elseif command == 'stats' then
    
        gw.Write('common: %d sconn, %d fconn, %d leave, %d disco', 
                gwCommonChannel.stats.sconn, gwCommonChannel.stats.fconn,
                gwCommonChannel.stats.leave, gwCommonChannel.stats.disco)
        if GreenWall.ochat then
            gw.Write('officer: %d sconn, %d fconn, %d leave, %d disco', 
                    gwOfficerChannel.stats.sconn, gwOfficerChannel.stats.fconn,
                    gwOfficerChannel.stats.leave, gwOfficerChannel.stats.disco)
        end
    
    elseif command == 'version' then

        gw.Write('GreenWall version %s.', gwVersion)

    else
    
        gw.Error('Unknown command: %s', command)

    end

end


--[[-----------------------------------------------------------------------

Initialization

--]]-----------------------------------------------------------------------

function GreenWall_OnLoad(self)

    -- 
    -- Set up slash commands
    --
    SLASH_GREENWALL1 = '/greenwall'
    SLASH_GREENWALL2 = '/gw'
    SlashCmdList['GREENWALL'] = GwSlashCmd
    
    --
    -- Trap the events we are interested in
    --
    self:RegisterEvent('ADDON_LOADED')
    self:RegisterEvent('CHANNEL_UI_UPDATE')
    self:RegisterEvent('CHAT_MSG_ADDON')
    self:RegisterEvent('CHAT_MSG_CHANNEL')
    self:RegisterEvent('CHAT_MSG_CHANNEL_JOIN')
    self:RegisterEvent('CHAT_MSG_CHANNEL_LEAVE')
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE')
    self:RegisterEvent('CHAT_MSG_GUILD')
    self:RegisterEvent('CHAT_MSG_OFFICER')
    self:RegisterEvent('CHAT_MSG_GUILD_ACHIEVEMENT')
    self:RegisterEvent('CHAT_MSG_SYSTEM')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('PLAYER_GUILD_UPDATE')
    self:RegisterEvent('PLAYER_LOGIN')
    
    --
    -- Add a tab to the Interface Options panel.
    --
    self.name = 'GreenWall ' .. gwVersion
    self.refresh = function (self) GreenWallInterfaceFrame_OnShow(self) end
    self.okay = function (self) GreenWallInterfaceFrame_SaveUpdates(self) end
    self.cancel = function (self) return end
    self.default = function (self) GreenWallInterfaceFrame_SetDefaults(self) end
    InterfaceOptions_AddCategory(self)
        
end


--- Initialize options to default values.
-- @param soft If true, set only undefined options to the default values.
local function GwSetDefaults(soft)

    if soft == nil then
        soft = false
    else
        soft = true
    end

    if GreenWall == nil then
        GreenWall = {}
    end

    for k, p in pairs(gwDefaults) do
        if not soft or GreenWall[k] == nil then
            GreenWall[k] = p['default']
        end
    end
    GreenWall.version = gwVersion

    if GreenWallLog == nil then
        GreenWallLog = {}
    end

end


--[[-----------------------------------------------------------------------

Frame Event Functions

--]]-----------------------------------------------------------------------

function GreenWall_OnEvent(self, event, ...)

    --
    -- Event switch
    --
    if event == 'ADDON_LOADED' and select(1, ...) == 'GreenWall' then
        
        --
        -- Initialize the saved variables
        --
        GwSetDefaults(true)

        --
        -- Thundercats are go!
        --
        gwAddonLoaded = true
        gw.Write('v%s loaded.', gwVersion)
        
        gw.Debug(GW_LOG_DEBUG, 'init: name=%s, realm=%s', gwPlayerName, gwRealmName)
        
    end            
        
    if gwAddonLoaded then
        gw.Debug(GW_LOG_DEBUG, 'on_event: event=%s', event)
    else
        return      -- early exit
    end

    local timestamp = time()

    if event == 'CHAT_MSG_CHANNEL' then
    
        local payload, sender, language, _, _, flags, _, 
                chanNum, _, _, counter, guid = select(1, ...)
        
        if chanNum == gwCommonChannel.number or chanNum == gwOfficerChannel.number then
        
            sender = GwGlobalName(sender)   -- Groom sender name.
        
            gw.Debug(GW_LOG_DEBUG, 'Rx<%d, %d, %s>: %s', chanNum, counter, sender, payload)
            gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gwPlayerName)

            local opcode, container, _, message = strsplit('#', payload, 4)
            
            if opcode == nil or container == nil or message == nil then
            
                gw.Debug(GW_LOG_NOTICE, 'rx_validation: invalid message format.')
                
            else
            
                if opcode == 'R' then
                
                    --
                    -- Incoming request
                    --
                    if message == 'reload' then 
                        local diff = timestamp - gwReloadHoldTime
                        gw.Write('Received configuration reload request from %s.', sender)
                        if diff >= gwReloadHoldInt then
                            gw.Debug(GW_LOG_INFO, 'on_event: initiating reload.')
                            gwReloadHoldTime = timestamp
                            gwCommonChannel.configured = false
                            gwOfficerChannel.configured = false
                            GuildRoster()
                        end
                    end
        
                elseif not GwCmp(sender, gwPlayerName) and container ~= gwContainerId then
                
                    if opcode == 'C' then
        
                        if chanNum == gwCommonChannel.number then
                            GwReplicateMessage('GUILD', sender, container, language, flags, message, counter, guid)
                        elseif chanNum == gwOfficerChannel.number then
                            GwReplicateMessage('OFFICER', sender, container, language, flags, message, counter, guid)
                        end
                        
                    elseif opcode == 'A' then
        
                        if GreenWall.achievements then
                            GwReplicateMessage('GUILD_ACHIEVEMENT', sender, container, language, flags, message, counter, guid)
                        end
        
                    elseif opcode == 'B' then
                
                        local action, target, arg = GwDecodeBroadcast(message)
                    
                        if action == 'join' then
                            if GreenWall.roster then
                                GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                        format(ERR_GUILD_JOIN_S, sender), counter, guid)
                            end
                        elseif action == 'leave' then
                            if GreenWall.roster then
                                GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                        format(ERR_GUILD_LEAVE_S, sender), counter, guid)
                            end
                        elseif action == 'remove' then
                            if GreenWall.rank then
                                GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                        format(ERR_GUILD_REMOVE_SS, target, sender), counter, guid)
                            end
                        elseif action == 'promote' then
                            if GreenWall.rank then
                                GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                        format(ERR_GUILD_PROMOTE_SSS, sender, target, arg), counter, guid)
                            end
                        elseif action == 'demote' then
                            if GreenWall.rank then
                                GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                        format(ERR_GUILD_DEMOTE_SSS, sender, target, arg), counter, guid)
                            end
                        end                                
                
                    end
                    
                end
                
            end
            
            --
            -- Check for corruption of outbound messages on the shared channels (e.g. modification by Identity).
            --
            if GwCmp(sender, gwPlayerName) then                
            
                local tx_hash = nil
                if chanNum == gwCommonChannel.number then
                    tx_hash = gwCommonChannel.tx_hash
                elseif chanNum == gwOfficerChannel.number then
                    tx_hash = gwOfficerChannel.tx_hash
                end
                
                if tx_hash ~= nil then
                    
                    local hash = crc.Hash(payload)
                    
                    -- Search the sent message hash table for a match.
                    if tx_hash[hash] == nil or tx_hash[hash] <= 0 then
                        gw.Debug(GW_LOG_DEBUG, 'rx_validate: tx_hash[0x%04X] not found', hash)
                        gw.Error('Message corruption detected.  Please disable add-ons that might modify messages on channel %d.', chanNum)
                    else
                        gw.Debug(GW_LOG_DEBUG, 'rx_validate: tx_hash[0x%04X] == %d', hash, tx_hash[hash])
                        tx_hash[hash] = tx_hash[hash] - 1
                        if tx_hash[hash] <= 0 then
                            tx_hash[hash] = nil
                        end
                    end
                    
                end
    
            end
             
        end
        
    elseif event == 'CHAT_MSG_GUILD' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'Rx<GUILD, %s>: %s', sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gwPlayerName)
        if GwCmp(sender, gwPlayerName) then
            GwSendConfederationMsg(gwCommonChannel, 'chat', message)
        end
    
    elseif event == 'CHAT_MSG_OFFICER' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'Rx<OFFICER, %s>: %s', sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gwPlayerName)
        if GwCmp(sender, gwPlayerName) and GreenWall.ochat then
            GwSendConfederationMsg(gwOfficerChannel, 'chat', message)
        end
    
    elseif event == 'CHAT_MSG_GUILD_ACHIEVEMENT' then
    
        local message, sender, _, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'Rx<ACHIEVEMENT, %s>: %s', sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gwPlayerName)
        if GwCmp(sender, gwPlayerName) then
            GwSendConfederationMsg(gwCommonChannel, 'achievement', message)
        end
    
    elseif event == 'CHAT_MSG_ADDON' then
    
        local prefix, message, dist, sender = select(1, ...)
        
        gw.Debug(GW_LOG_DEBUG, 'on_event: event=%s, prefix=%s, sender=%s, dist=%s, message=%s',
                event, prefix, sender, dist, message)
        gw.Debug(GW_LOG_DEBUG, 'Rx<ADDON(%s), %s>: %s', prefix, sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gwPlayerName)
        
        if prefix == 'GreenWall' and dist == 'GUILD' and not GwCmp(sender, gwPlayerName) then
        
            local type, command = strsplit('#', message)
            
            gw.Debug(GW_LOG_DEBUG, 'on_event: type=%s, command=%s', type, command)
            
            if type == 'C' then
            
                if command == 'officer' then
                    if GwIsOfficer() then
                        -- Let 'em know you have the authoritay!
                        GwSendContainerMsg('response', 'officer')
                    end
                end
            
            elseif type == 'R' then
            
                if command == 'officer' then
                    if gwFlagOwner then
                        -- Verify the claim
                        if GwIsOfficer(sender) then
                            if gwCommonChannel.owner then
                                gw.Debug(GW_LOG_INFO, 'on_event: granting owner status to $s.', sender)
                                SetChannelOwner(gwCommonChannel.name, sender)
                            end
                            gwFlagHandoff = true
                        end
                    end
                end
            
            end
            
        end
        
    elseif event == 'CHAT_MSG_CHANNEL_JOIN' then
    
        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'chan_join: channel=%s, player=%s', number, player)
        
        if number == gwCommonChannel.number then
            if GetCVar('guildMemberNotify') == '1' and GreenWall.roster then
                if gwComemberCache[player] then
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: hit %s', player)
                else
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: miss %s', player)
                    GwReplicateMessage('SYSTEM', nil, nil, nil, nil, format(ERR_FRIEND_ONLINE_SS, player, player), nil, nil)
                end
                gwComemberCache[player] = timestamp
                gw.Debug(GW_LOG_DEBUG, format('comember_cache: updated %s', player))
            end
        end
    
    elseif event == 'CHAT_MSG_CHANNEL_LEAVE' then
    
        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'chan_leave: channel=%s, player=%s', number, player)
        
        if number == gwCommonChannel.number then
            if GetCVar('guildMemberNotify') == '1' and GreenWall.roster then
                if gwComemberCache[player] then
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: hit %s', player)
                else
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: miss %s', player)
                    GwReplicateMessage('SYSTEM', nil, nil, nil, nil, format(ERR_FRIEND_OFFLINE_S, player), nil, nil)
                end
                gwComemberCache[player] = timestamp
                gw.Debug(GW_LOG_DEBUG, format('comember_cache: updated %s', player))
            end
        end
                        
    elseif event == 'CHANNEL_UI_UPDATE' then
    
        if gwGuildName ~= nil then
            GwRefreshComms()
        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE' then

        local action, _, _, _, _, _, type, number, name = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'chat_notice: type=%s, number=%s, name=%s, action=%s', type, number, name, action)
        
        if number == gwCommonChannel.number then
            
            if action == 'YOU_LEFT' then
                gwCommonChannel.stats.disco = gwCommonChannel.stats.disco + 1
                GwRefreshComms()
            end
        
        elseif number == gwOfficerChannel.number then
            
            if action == 'YOU_LEFT' then
                gwOfficerChannel.stats.disco = gwOfficerChannel.stats.disco + 1
                GwRefreshComms()
            end
        
        elseif type == 1 then
        
            if action == 'YOU_JOINED' or action == 'YOU_CHANGED' then
                gw.Debug(GW_LOG_INFO, 'on_event: General joined, unblocking reconnect.')
                gwFlagChatBlock = false
                GwRefreshComms()
            end
                
        end

    elseif event == 'CHAT_MSG_SYSTEM' then

        local message = select(1, ...)
        
        gw.Debug(GW_LOG_DEBUG, 'on_event: system message: %s', message)
        
        local pat_online = string.gsub(format(ERR_FRIEND_ONLINE_SS, '(.+)', '(.+)'), '%[', '%%[')
        local pat_offline = format(ERR_FRIEND_OFFLINE_S, '(.+)')
        local pat_join = format(ERR_GUILD_JOIN_S, gwPlayerName)
        local pat_leave = format(ERR_GUILD_LEAVE_S, gwPlayerName)
        local pat_quit = format(ERR_GUILD_QUIT_S, gwPlayerName)
        local pat_removed = format(ERR_GUILD_REMOVE_SS, gwPlayerName, '(.+)')
        local pat_kick = format(ERR_GUILD_REMOVE_SS, '(.+)', gwPlayerName)
        local pat_promote = format(ERR_GUILD_PROMOTE_SSS, gwPlayerName, '(.+)', '(.+)')
        local pat_demote = format(ERR_GUILD_DEMOTE_SSS, gwPlayerName, '(.+)', '(.+)')
        
        if message:match(pat_online) then
        
            local _, player = message:match(pat_online)
            gw.Debug(GW_LOG_DEBUG, 'player_status: player %s online', player)
            gwComemberCache[player] = timestamp
            gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', player)
        
        elseif message:match(pat_offline) then
        
            local player = message:match(pat_offline)
            gw.Debug(GW_LOG_DEBUG, 'player_status: player %s offline', player)
            gwComemberCache[player] = timestamp
            gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', player)
        
        elseif message:match(pat_join) then

            -- We have joined the guild.
            gw.Debug(GW_LOG_DEBUG, 'on_event: guild join detected.')
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('join'))

        elseif message:match(pat_leave) or message:match(pat_quit) or message:match(pat_removed) then
        
            -- We have left the guild.
            gw.Debug(GW_LOG_DEBUG, 'on_event: guild quit detected.')
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('leave'))
            if GwIsConnected(gwCommonChannel) then
                GwAbandonChannel(gwCommonChannel)
                gwCommonChannel = GwNewChannelTable()
            end
            if GwIsConnected(gwOfficerChannel) then
                GwAbandonChannel(gwOfficerChannel)
                gwOfficerChannel = GwNewChannelTable()
            end

        elseif message:match(pat_kick) then
            
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('remove', message:match(pat_kick)))
        
        elseif message:match(pat_promote) then
            
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('promote', message:match(pat_promote)))
        
        elseif message:match(pat_demote) then
            
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('demote', message:match(pat_demote)))
        
        end

    elseif event == 'GUILD_ROSTER_UPDATE' then
    
        gwGuildName = GwGuildName()
        if gwGuildName == nil then
            gw.Debug(GW_LOG_NOTICE, 'guild_info: co-guild unavailable.')
            return false
        else
            gw.Debug(GW_LOG_DEBUG, 'guild_info: co-guild is %s.', gwGuildName)
        end
            
        local holdtime = timestamp - gwConfigHoldTime
        gw.Debug(GW_LOG_DEBUG, 'config_reload: common_conf=%s, officer_conf=%s, holdtime=%d, holdint=%d',
                tostring(gwCommonChannel.configured), tostring(gwOfficerChannel.configured), holdtime, gwConfigHoldInt)

        -- Update the configuration
        if not gwCommonChannel.configured then
            GwGetGuildInfoConfig(gwCommonChannel)
        end
        
        if GreenWall.ochat then
            if not gwOfficerChannel.configured then
                GwGetOfficerNoteConfig(gwOfficerChannel)
            end
        end
        
        -- Periodic check for updated configuration.
        if holdtime >= gwConfigHoldInt then
            GwGetGuildInfoConfig(gwCommonChannel)
            if GreenWall.ochat then
                GwGetOfficerNoteConfig(gwOfficerChannel)
            end
            gwConfigHoldTime = timestamp
        end

        GwRefreshComms()

    elseif event == 'PLAYER_ENTERING_WORLD' then
    
        -- Added for 4.1
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix("GreenWall")
        end

    elseif event == 'PLAYER_GUILD_UPDATE' then
    
        -- Query the guild info.
        GuildRoster()
        
    elseif event == 'PLAYER_LOGIN' then

        -- Initiate the comms
        GwPrepComms()
        
        -- Defer joining to allow General to grab slot 1
        gwFlagChatBlock = true
        
        -- Timer in case player has left General at some point
        gwChatBlockTimestamp = timestamp + gwChatBlockTimeout
    
    end

    --
    -- Take care of our lazy timers
    --
    
    if gwFlagChatBlock then
        if gwChatBlockTimestamp <= timestamp then
            -- Give up
            gw.Debug(GW_LOG_INFO, 'on_event: reconnect deferral timeout expired.')
            gwFlagChatBlock = false
            GwRefreshComms()
        end
    end
    
    --
    -- Prune co-member cache.
    --
    local index, value
    for index, value in pairs(gwComemberCache) do
        if timestamp > gwComemberCache[index] + gwComemberTimeout then
            gwComemberCache[index] = nil
            gw.Debug(GW_LOG_DEBUG, 'comember_cache: deleted %s', index)
        end
    end
        
end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
