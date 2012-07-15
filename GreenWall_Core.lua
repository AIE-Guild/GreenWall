--[[-----------------------------------------------------------------------

    $Id$

    $HeadURL$

    Copyright (c) 2010-2012; Mark Rogaski.

    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

        * Redistributions of source code must retain the above copyright
          notice, this list of conditions and the following disclaimer.

        * Redistributions in binary form must reproduce the above
          copyright notice, this list of conditions and the following
          disclaimer in the documentation and/or other materials provided
          with the distribution.

        * Neither the name of the copyright holder nor the names of any
          contributors may be used to endorse or promote products derived
          from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
    A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
    OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


--]]-----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Global Variables

--]]-----------------------------------------------------------------------

--
-- Add-on metadata
--

local gwVersion = GetAddOnMetadata('GreenWall', 'Version');

local gwDefaults = {
    tag             = { default=true,   desc="co-guild tagging" },
    achievements    = { default=false,  desc="co-guild achievement announcements" },
    roster          = { default=true,   desc="co-guild roster announcements" },
    rank            = { default=false,  desc="co-guild rank announcements" },
    debug           = { default=0,      desc="debugging level" },
    verbose         = { default=false,  desc="verbose debugging" },
    log             = { default=false,  desc="event logging" },
    logsize         = { default=2048,   desc="maximum log buffer size" },
    ochat           = { default=false,  desc="officer chat bridging" },
};

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
        -- Toggle display of confederation join and leave messages.
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
 
]];
        
--
-- Player variables
--

local gwPlayerName      = UnitName('Player');
local gwGuildName       = nil;  -- wait until guild info is retrieved. 
local gwPlayerLanguage  = GetDefaultLanguage('Player');


--
-- Co-guild variables
--

local gwContainerId     = nil;
local gwPeerTable       = {};
local gwCommonChannel 	= {};
local gwOfficerChannel 	= {};


--
-- State variables
--

local gwAddonLoaded     = false;
local gwFlagChatBlock   = true;
local gwStateSendWho    = 0;


--
-- Guild options
--
local gwOptMinVersion   = gwVersion;
local gwOptChanKick     = false;
local gwOptChanBan      = false;


--
-- Timers and thresholds
--

-- Timeout for General chat barrier
local gwChatBlockTimeout    = 30;
local gwChatBlockTimestamp  = 0;

-- Configuration hold-down
local gwConfigHoldInt   = 300;
local gwConfigHoldTime  = 0;

-- Hold-down for reload requests
local gwReloadHoldInt   = 180;
local gwReloadHoldTime  = 0;

-- Channel ownership handoff
local gwHandoffTimeout  = 15;
local gwHandoffTimer    = nil;


--
-- Tables external to functions
--

local gwChannelTable    = {};
local gwChatWindowTable = {};
local gwFrameTable      = {};
local gwGuildCheck      = {};


--[[-----------------------------------------------------------------------

Convenience Functions

--]]-----------------------------------------------------------------------

--- Add a message to the log file
-- @param msg A string to write to the log.
-- @param level (optional) The log level of the message.  Defaults to 0.
local function GwLog(msg)
    if GreenWall ~= nil and GreenWall.log and GreenWallLog ~= nil then
        local ts = date('%Y-%m-%d %H:%M:%S');
        tinsert(GreenWallLog, format('%s -- %s', ts, msg));
        while # GreenWallLog > GreenWall.logsize do
            tremove(GreenWallLog, 1);
        end
    end
end


--- Write a message to the default chat frame.
-- @param msg The message to send.
local function GwWrite(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r ' .. msg);
    GwLog(msg);
end


--- Write an error message to the default chat frame.
-- @param msg The error message to send.
local function GwError(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r |cffff6000[ERROR] ' .. msg);
    GwLog('[ERROR] ' .. msg);
end


--- Write a debugging message to the default chat frame with a detail level.
-- Messages will be filtered with the "/greenwall debug <level>" command.
-- @param level A positive integer specifying the debug level to display this under.
-- @param msg The message to send.
local function GwDebug(level, msg)

    if GreenWall ~= nil then
        if level <= GreenWall.debug then
            GwLog(format('[DEBUG/%d] %s', level, msg));
            if GreenWall.verbose then
                DEFAULT_CHAT_FRAME:AddMessage(format('|cffabd473GreenWall:|r |cff778899[DEBUG/%d] %s|r', level, msg));
            end
        end
    end
    
end


--- CRC-16-CCITT
-- @param str The string to hash.
-- @return The CRC hash.
local function GwStringHash(str)

    if text == nil then
        text = '';
    end
    
    local crc = 0xffff;
    
    for i = 1, #str do
    
        c = str:byte(i);
        crc = bit.bxor(crc, c);

        for j = 1, 8 do

            local k = bit.band(crc, 1);
            crc = bit.rshift(crc, 1);

            if k ~= 0 then
                crc = bit.bxor(crc, 0x8408);
            end

        end

    end
    
    return crc;
end

--- Check if a connection exists to the common chat.
-- @param chan A channel control table.
-- @return True if connected, otherwise false.
local function GwIsConnected(chan)

    if chan.name then
        chan.number = GetChannelName(chan.name);
        GwDebug(5, format('conn_check: chan_name=<<%04X>>, chan_id=%d', GwStringHash(chan.name), chan.number));
        if chan.number ~= 0 then
            return true;
        end
    end
    
    return false;
            
end


--- Check a target player for officer status in the same container guild.
-- @param target The name of the player to check.
-- @return True is the target has access to officer chat, false otherwise.
local function GwIsOfficer(target)

    local rank;
    local ochat = false;
    
    if target == nil then
        target = 'Player';
    end
    _, _, rank = GetGuildInfo(target);
    
    if rank == 0 then
        ochat = true
    else
        GuildControlSetRank(rank);
        _, _, ochat = GuildControlGetRankFlags();
    end
    
    if ochat then
        GwDebug(5, format('is_officer: %s is rank %d and can see ochat', target, rank));
    else
        GwDebug(5, format('is_officer: %s is rank %d and cannot see ochat', target, rank));
    end
    
    return ochat;

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
        configured = false;
        dirty = false,
        owner = false,
        handoff = false,
        queue = {},
        stats = {
            sconn = 0,
            fconn = 0,
            leave = 0,
            disco = 0
        }
    }
    return tab;
end


--- Check a guild for peer status.
-- @param guild The name of the guild to check.
-- @return True if the target guild is a peer co-guild, false otherwise.
local function GwIsPeer(guild)
    for i, v in pairs(gwPeerTable) do
        if v == guild then
            return true;
        end
    end
    return false;
end


--- Check a guild for membership within the confederation.
-- @param guild The name of the guild to check.
-- @return True if the target guild is in the confederation, false otherwise.
local function GwIsContainer(guild)
    if guild == gwGuildName then
        return gwContainerId ~= nil;
    else
        return GwIsPeer(guild);
    end
end


--- Finds channel roles for a player.
-- @param chan Control table for the channel.
-- @param name Name of the player to check.
-- @return True if target is the channel owner, false otherwise.
-- @return True if target is a channel moderator, false otherwise.
local function GwChannelRoles(chan, name)
        
    if name == nil then
        name = gwPlayerName;
    end
    
    if chan.number ~= 0 then
        local _, _, _, _, count = GetChannelDisplayInfo(chan.number);
        for i = 1, count do
            local target, town, tmod = GetChannelRosterInfo(chan.number, i);
            if target == name then
                return town, tmod;
            end
        end
    end
    
    return;
    
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
    
    local event;
    if target == 'GUILD' then
        event = 'CHAT_MSG_GUILD';
    elseif target == 'OFFICER' then
        event = 'CHAT_MSG_OFFICER';
    elseif target == 'GUILD_ACHIEVEMENT' then
        event = 'CHAT_MSG_GUILD_ACHIEVEMENT';
    elseif target == 'SYSTEM' then
        event = 'CHAT_MSG_SYSTEM';
    else
        GwError('invalid target channel: ' .. target);
        return;
    end
    
    if GreenWall.tag then
        message = format('<%s> %s', container, message);
    end
        
    for i = 1, NUM_CHAT_WINDOWS do

        gwFrameTable = { GetChatWindowMessages(i) }
        
        for _, v in ipairs(gwFrameTable) do
                        
            if v == target then
                    
                local frame = 'ChatFrame' .. i;
                if _G[frame] then
                    GwDebug(3, format('Cp<%s/%s, *, %s>: %s', frame, target, sender, message));
                    
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
                            counter, 
                            guid
                        );
                end
                break;
                        
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
        sync = false;
        GwDebug(5, format('coguild_msg: type=%s, async, message=%s', type, message));
    else
        GwDebug(5, format('coguild_msg: type=%s, sync, message=%s', type, message));
    end

    -- queue messages id not connected
    if not GwIsConnected(chan) then
        if not sync then 
            tinsert(chan.queue, { type, message });
            GwDebug(2, format('coguild_msg: queued %s message: %s', type, message));
        end
        return;
    end

    local opcode;    
    if type == nil then
        GwDebug(2, 'coguild_msg: missing arguments.');
        return;
    elseif type == 'chat' then
        opcode = 'C';
    elseif type == 'achievement' then
        opcode = 'A';
    elseif type == 'broadcast' then
        opcode = 'B';
    elseif type == 'notice' then
        opcode = 'N';
    elseif type == 'request' then
        opcode = 'R';
    elseif type == 'addon' then
        opcode = 'M';
    else
        GwDebug(2, format('coguild_msg: unknown message type: %s', type));
        return;
    end
    
    local coguild;
    if gwContainerId == nil then
        GwDebug(2, format('coguild_msg: missing container ID.'));
        coguild = '-';
    else
        coguild = gwContainerId;
    end
    
    if message == nil then
        message = '';
    end
    
    local payload = strsub(strjoin('#', opcode, gwContainerId, '', message), 1, 255);
    GwDebug(3, format('Tx<%d, %s>: %s', chan.number, gwPlayerName, payload));
    SendChatMessage(payload , "CHANNEL", nil, chan.number); 

end


--- Sends an encoded message to the rest of the same container on the add-on channel.
-- @param type The message type.
-- @field request Command request.
-- @field response Command response.
-- @field info Informational message.
-- @param message Text of the message.
local function GwSendContainerMsg(type, message)

    GwDebug(5, format('cont_msg: type=%s, message=%s', type, message));

    local opcode;
    
    if type == nil then
        GwDebug(2, 'cont_msg: missing arguments.');
        return;
    elseif type == 'request' then
        opcode = 'C';
    elseif type == 'response' then
        opcode = 'R';
    elseif type == 'info' then
        opcode = 'I';
    else
        GwDebug(2, format('cont_msg: unknown message type: %s', type));
        return;
    end

    local payload = strsub(strjoin('#', opcode, message), 1, 255);
    GwDebug(3, format('Tx<ADDON/GUILD, *, %s>: %s', gwPlayerName, payload));
    SendAddonMessage('GreenWall', payload, 'GUILD');
    
end


--- Encode a broadcast message.
-- @param action The action type.
-- @param target The target of the action (optional).
-- @param arg Additional data (optional).
-- @return An encoded string.
local function GwEncodeBroadcast(action, target, arg)
    return strjoin(':', tostring(action), tostring(target), tostring(arg));
end


--- Decode a broadcast message.
-- @param string An encoded string.
-- @return The action type.
-- @return The target of the action (optional).
-- @return Additional data (optional).
local function GwDecodeBroadcast(string)
    local elem = { strsplit(':', string) };
    return elem[1], elem[2], elem[3];
end


--- Leave a shared confederation channel.
-- @param chan The channel control table.
local function GwLeaveChannel(chan)

    local id, name = GetChannelName(chan.number);
    if name then
        GwDebug(1, format('chan_leave: name=<<%04X>>, number=%d', GwStringHash(name), chan.number));
        LeaveChannelByName(name);
        chan.number = 0;
        chan.stats.leave = chan.stats.leave + 1;
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
        chan.number = GetChannelName(chan.name);
        if chan.number == 0 then
            JoinTemporaryChannel(chan.name, chan.password);
            chan.number = GetChannelName(chan.name);
        end
        
        if chan.number == 0 then

            GwError(format('cannot create communication channel: %s', chan.number));
            chan.stats.fconn = chan.stats.fconn + 1;
            return false;

        else
        
            GwDebug(2, format('chan_join: name=<<%04X>>, number=%d', GwStringHash(chan.name), chan.number));
            GwWrite(format('Connected to confederation on channel %d.', chan.number));
            
            chan.stats.sconn = chan.stats.sconn + 1;
            
            --
            -- Check for default permissions
            --
            DisplayChannelOwner(chan.number);
            
            --
            -- Hide the channel
            --
            for i = 1, 10 do
                gwChatWindowTable = { GetChatWindowMessages(i) };
                for j, v in ipairs(gwChatWindowTable) do
                    if v == chan.name then
                        local frame = format('ChatFrame%d', i);
                        if _G[frame] then
                            GwDebug(2, format('chan_join: hiding channel: name=<<%04X>>, number=%d, frame=%s', 
                                    GwStringHash(chan.name), chan.number, frame));
                            ChatFrame_RemoveChannel(frame, chan.name);
                        end
                    end
                end
            end
            
            --
            -- Request permissions if necessary
            --
            if GwIsOfficer() then
                GwSendContainerMsg('response', 'officer');
            end
            
            return true;
            
        end
        
    end

    return false;

end


--- Drain a channel's message queue.
-- @param chan Channel control table.
-- @return Number of messages flushed.
local function GwFlushChannel(chan)
    GwDebug(2, format('chan_flush: draining channel queue: name=<<%04X>>, number=%d', 
            GwStringHash(chan.name), chan.number));
    count = 0;
    while true do
        rec = tremove(chan.queue, 1);
        if rec == nil then
            break;
        else
            GwSendConfederationMsg(chan, rec[1], rec[2], true);
            count = count + 1;
        end
    end
    return count;
end


--- Clear confederation configuration and request updated guild roster 
-- information from the server.
local function GwPrepComms()
    
    GwDebug(2, 'prep_comms: initiating reconnect, querying guild roster.');
    
    gwContainerId   = nil;
    gwPeerTable     = {};
    gwCommonChannel = GwNewChannelTable();
    gwOfficerChannel = GwNewChannelTable();

    GuildRoster();
    
end


--- Parse the guild information page to gather configuration information.
-- @param chan Channel control table to update.
-- @return True if successful, false otherwise.
local function GwGetGuildInfoConfig(chan)

    GwDebug(2, 'guild_info: parsing guild information.');

    local info = GetGuildInfoText();
    
    if info == '' then

        GwDebug(2, 'guild_info: not yet available.');
        return false;
    
    else    

        -- Make sure we know which co-guild we are in.
        if gwGuildName == nil or gwGuildName == '' then
            gwGuildName = GetGuildInfo('Player');
            if gwGuildName == nil then
                GwDebug(2, 'guild_info: co-guild unavailable.');
                return false;
            else
                GwDebug(2, format('guild_info: co-guild is %s.', gwGuildName));
            end
        end
    
        -- We will rebuild the list of peer container guilds
        wipe(gwPeerTable);

        for buffer in gmatch(info, 'GW:([^\n]+)') do
        
            if buffer ~= nil then
                        
                buffer = strtrim(buffer);
                local vector = { strsplit(':', buffer) };
            
                if vector[1] == 'c' then
                
                    if chan.name ~= vector[2] then
                        chan.name = vector[2];
                        chan.dirty = true;
                    end
                    
                    if chan.password ~= vector[3] then
                        chan.password = vector[3];
                        chan.dirty = true;
                    end
                        
                    GwDebug(2, format('guild_info: channel=<<%04X>>, password=<<%04X>>', 
                            GwStringHash(chan.name), GwStringHash(chan.password)));

                elseif vector[1] == 'o' then
                
                    local optlist = { strsplit(',', gsub(vector[2], '%s+', '')) };
                
                    for i, opt in ipairs(optlist) do
                    
                        local k, v = strsplit('=', opt);
                    
                        k = strlower(k);
                        v = strlower(v);
                        
                        if k == 'mv' then
                            if strmatch(v, '^%d+%.%d+%.%d+%w*$') then
                                gwOptMinVersion = v;
                                GwDebug(2, format('guild_info: minimum version is %s', gwOptMinVersion));
                            end
                        elseif k == 'cd' then
                            if v == 'k' then
                                gwOptChanKick = true;
                                GwDebug(2, 'guild_info: channel defense mode is kick.');
                            elseif v == 'kb' then
                                gwOptChanBan = true;
                                GwDebug(2, 'guild_info: channel defense mode is kick/ban.');
                            else
                                GwDebug(2, 'guild_info: channel defense mode is none.');
                            end
                        end
                        
                    end
                                    
                elseif vector[1] == 'p' then
        
                    if vector[2] == gwGuildName then
                        gwContainerId = vector[3];
                        GwDebug(2, format('guild_info: container=%s (%s)', gwGuildName, gwContainerId));
                    else 
                        gwPeerTable[vector[3]] = vector[2];
                        GwDebug(2, format('guild_info: peer=%s (%s)', vector[2], vector[3]));
                    end
                    
                end
        
            end
    
        end
            
        chan.configured = true;
        GwDebug(1, 'guild_info: configuration updated.');
            
    end
        
    return true;
        
end


--- Parse the officer note of the guild leader to gather configuration information.
-- @param chan Channel control table to update.
-- @return True if successful, false otherwise.
local function GwGetOfficerNoteConfig(chan)

    -- Avoid pointless work if we're not an officer
    if not GwIsOfficer() then
        return false;
    end
    
    -- Find the guild leader
    local n = GetNumGuildMembers();
    local leader = 0;
    local config = '';

    for i = 1, n do
        name, _, rank, _, _, _, _, note = GetGuildRosterInfo(i);
        if rank == 0 then
            GwDebug(2, format('officer_note: parsing officer note for %s.', name));
            leader = 1;
            config = note;
            break;
        end
    end
    
    if leader == 0 then
        return false;
    else

        -- update the channel control table
        chan.name, chan.password = config:match('GW:a:([%w_]+):([%w_]*)');
        if chan.name ~= nil then
            chan.configured = true;
            GwDebug(2, format('officer_note: channel=<<%04X>>, password=<<%04X>>', 
                    GwStringHash(chan.name), GwStringHash(chan.password)));
            return true;
        else
            return false;
        end        
    end
    
end


--- Parse confederation configuration and connect to the common channel.
local function GwRefreshComms()

    GwDebug(2, 'refresh_comms: refreshing communication channels.');

    --
    -- Connect if necessary
    --
    if GwIsConnected(gwCommonChannel) then    
        if gwCommonChannel.dirty then
            GwDebug(2, 'refresh_comms: common channel dirty flag set.');
            GwLeaveChannel(gwCommonChannel);
            if GwJoinChannel(gwCommonChannel) then
                GwFlushChannel(gwCommonChannel);
            end
            gwCommonChannel.dirty = false;
        end
    elseif gwFlagChatBlock then
        GwDebug(2, 'refresh_comms: deferring common channel refresh, General not yet joined.');
    else    
        if GwJoinChannel(gwCommonChannel) then
            GwFlushChannel(gwCommonChannel);
        end
    end

    if GreenWall.ochat then
        if GwIsConnected(gwOfficerChannel) then    
            if gwOfficerChannel.dirty then
                GwDebug(2, 'refresh_comms: common channel dirty flag set.');
                GwLeaveChannel(gwOfficerChannel);
                if GwJoinChannel(gwOfficerChannel) then
                    GwFlushChannel(gwOfficerChannel);
                end
                gwOfficerChannel.dirty = false;
            end
        elseif gwFlagChatBlock then
            GwDebug(2, 'refresh_comms: deferring officer channel refresh, General not yet joined.');
        else    
            if GwJoinChannel(gwOfficerChannel) then
                GwFlushChannel(gwOfficerChannel);
            end
        end
    end

end


--- Send a configuration reload request to the rest of the confederation.
local function GwForceReload()
    if GwIsConnected(gwCommonChannel) then
        GwSendConfederationMsg(gwCommonChannel, 'request', 'reload');
    end 
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
        return false;
    else
        if gwDefaults[key] ~= nil then
            local default = gwDefaults[key]['default'];
            local desc = gwDefaults[key]['desc']; 
            if type(default) == 'boolean' then
                if val == nil or val == '' then
                    if GreenWall[key] then
                        GwWrite(desc .. ' turned ON.');
                    else
                        GwWrite(desc .. ' turned OFF.');
                    end
                elseif val == 'on' then
                    GreenWall[key] = true;
                    GwWrite(desc .. ' turned ON.');
                elseif val == 'off' then
                    GreenWall[key] = false;
                    GwWrite(desc .. ' turned OFF.');
                else
                    GwError(format('invalid argument for %s: %s', desc, val));
                end
                return true;
            elseif type(default) == 'number' then
                if val == nil or val == '' then
                    if GreenWall[key] then
                        GwWrite(format('%s set to %d.', desc, GreenWall[key]));
                    end
                elseif val:match('^%d+$') then
                    GreenWall[key] = val + 0;
                    GwWrite(format('%s set to %d.', desc, GreenWall[key]));
                else
                    GwError(format('invalid argument for %s: %s', desc, val));
                end
                return true;
            end
        end
    end
    return false;
end


local function GwSlashCmd(message, editbox)

    --
    -- Parse the command
    --
    local command, argstr = message:match('^(%S*)%s*(%S*)%s*');
    command = command:lower();
    
    GwDebug(4, format('slash_cmd: command=%s, args=%s', command, argstr));
    
    if command == nil or command == '' or command == 'help' then
    
        for line in string.gmatch(gwUsage, '([^\n]*)\n') do
            GwWrite(line);
        end
    
    elseif GwCmdConfig(command, argstr) then
    
        -- Some special handling here
        if command == 'logsize' then
            while # GreenWallLog > GreenWall.logsize do
                tremove(GreenWallLog, 1);
            end
        elseif command == 'ochat' then
            GwGetOfficerNoteConfig(gwOfficerChannel);
            GwRefreshComms();
        end
    
    elseif command == 'reload' then
    
        GwForceReload();
        GwWrite('Broadcast configuration reload request.');
    
    elseif command == 'refresh' then
    
        GwRefreshComms();
        GwWrite('Refreshed communication link.');
    
    elseif command == 'status' then
    
        GwWrite('container=' .. tostring(gwContainerId));
        GwWrite(format('common: chan=<<%04X>>, num=%d, pass=<<%04X>>, connected=%s',
                GwStringHash(gwCommonChannel.name), 
                tostring(gwCommonChannel.number), 
                GwStringHash(gwCommonChannel.password),
                tostring(GwIsConnected(gwCommonChannel))
            ));
        if GreenWall.ochat then
            GwWrite(format('officer: chan=<<%04X>>, num=%d, pass=<<%04X>>, connected=%s',
                    GwStringHash(gwOfficerChannel.name), 
                    tostring(gwOfficerChannel.number), 
                    GwStringHash(gwOfficerChannel.password),
                    tostring(GwIsConnected(gwOfficerChannel))
                ));
        end
        
        GwWrite(format('hold_down=%d/%d', (time() - gwConfigHoldTime), gwConfigHoldInt));
        -- GwWrite('chan_kick=' .. tostring(gwOptKick));
        -- GwWrite('chan_ban=' .. tostring(gwOptBan));
        
        for i, v in pairs(gwPeerTable) do
            GwWrite(format('peer[%s] => %s', i, v));
        end
    
        GwWrite('version='      .. gwVersion);
        GwWrite('min_version='  .. gwOptMinVersion);
        
        GwWrite('tag='          .. tostring(GreenWall.tag));
        GwWrite('achievements=' .. tostring(GreenWall.achievements));
        GwWrite('roster='       .. tostring(GreenWall.roster));
        GwWrite('rank='         .. tostring(GreenWall.rank));
        GwWrite('debug='        .. tostring(GreenWall.debug));
        GwWrite('verbose='      .. tostring(GreenWall.verbose));
        GwWrite('log='          .. tostring(GreenWall.log));
        GwWrite('logsize='      .. tostring(GreenWall.logsize));
    
    elseif command == 'stats' then
    
        GwWrite(format('common: %d sconn, %d fconn, %d leave, %d disco', 
                gwCommonChannel.stats.sconn, gwCommonChannel.stats.fconn,
                gwCommonChannel.stats.leave, gwCommonChannel.stats.disco));
        if GreenWall.ochat then
            GwWrite(format('officer: %d sconn, %d fconn, %d leave, %d disco', 
                    gwOfficerChannel.stats.sconn, gwOfficerChannel.stats.fconn,
                    gwOfficerChannel.stats.leave, gwOfficerChannel.stats.disco));
        end
    
    elseif command == 'version' then

        GwWrite(format('GreenWall version %s.', gwVersion));

    else
    
        GwError(format('Unknown command: %s', command));

    end

end


--[[-----------------------------------------------------------------------

Initialization

--]]-----------------------------------------------------------------------

function GreenWall_OnLoad(self)

    -- 
    -- Set up slash commands
    --
    SLASH_GREENWALL1 = '/greenwall';
    SLASH_GREENWALL2 = '/gw';    
    SlashCmdList['GREENWALL'] = GwSlashCmd;
    
    --
    -- Trap the events we are interested in
    --
    self:RegisterEvent('ADDON_LOADED');
    self:RegisterEvent('CHANNEL_UI_UPDATE');
    self:RegisterEvent('CHAT_MSG_ADDON');
    self:RegisterEvent('CHAT_MSG_CHANNEL');
    -- self:RegisterEvent('CHAT_MSG_CHANNEL_JOIN');
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE');
    -- self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE_USER');
    self:RegisterEvent('CHAT_MSG_GUILD');
    self:RegisterEvent('CHAT_MSG_OFFICER');
    self:RegisterEvent('CHAT_MSG_GUILD_ACHIEVEMENT');
    self:RegisterEvent('CHAT_MSG_SYSTEM');
    self:RegisterEvent('GUILD_ROSTER_UPDATE');
    self:RegisterEvent('PLAYER_ENTERING_WORLD');
    self:RegisterEvent('PLAYER_GUILD_UPDATE');
    self:RegisterEvent('PLAYER_LOGIN');
    
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
        if GreenWall == nil then
            GreenWall = {};
        end
        for k, p in pairs(gwDefaults) do
            if GreenWall[k] == nil then
                GreenWall[k] = p['default'];
            end
        end
        GreenWall.version = gwVersion;

        if GreenWallLog == nil then
            GreenWallLog = {};
        end

        --
        -- Thundercats are go!
        --
        gwAddonLoaded = true;
        GwWrite(format('v%s loaded.', gwVersion));
        
    end            
        
    if gwAddonLoaded then
        GwDebug(4, format('on_event: event=%s', event));
    else
        return;  -- early exit
    end


    if event == 'CHAT_MSG_CHANNEL' then
    
        local payload, sender, language, _, _, flags, _, 
                chanNum, _, _, counter, guid = select(1, ...);
                
        if chanNum == gwCommonChannel.number then
        
            GwDebug(3, format('Rx<%d, %s>: %s', chanNum, sender, payload));
            
            local opcode, container, _, message = payload:match('^(%a)#(%w+)#([^#]*)#(.*)');
            
            if opcode == 'C' and sender ~= gwPlayerName and container ~= gwContainerId then

                GwReplicateMessage('GUILD', sender, container, language, flags,
                        message, counter, guid);
        
            elseif opcode == 'A' and sender ~= gwPlayerName and container ~= gwContainerId then

                if GreenWall.achievements then
                    GwReplicateMessage('GUILD_ACHIEVEMENT', sender, container, language, flags, message, counter, guid);
                end

            elseif opcode == 'B' and sender ~= gwPlayerName and container ~= gwContainerId then
            
                local action, target, arg = GwDecodeBroadcast(message);
                
                if action == 'join' then
                    if GreenWall.roster then
                        GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                format(ERR_GUILD_JOIN_S, sender), counter, guid);
                    end
                elseif action == 'leave' then
                    if GreenWall.roster then
                        GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                format(ERR_GUILD_LEAVE_S, sender), counter, guid);
                    end
                elseif action == 'remove' then
                    if GreenWall.rank then
                        GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                format(ERR_GUILD_REMOVE_SS, target, sender), counter, guid);
                    end
                elseif action == 'promote' then
                    if GreenWall.rank then
                        GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                format(ERR_GUILD_PROMOTE_SSS, sender, target, arg), counter, guid);
                    end
                elseif action == 'demote' then
                    if GreenWall.rank then
                        GwReplicateMessage('SYSTEM', sender, container, language, flags, 
                                format(ERR_GUILD_DEMOTE_SSS, sender, target, arg), counter, guid);
                    end
                end                    
            
            elseif opcode == 'R' then
            
                --
                -- Incoming request
                --
                if message:match('^reload(%w.*)?$') then 
                    local diff = time() - gwReloadHoldTime;
                    GwWrite(format('Received configuration reload request from %s.', sender));
                    if diff >= gwReloadHoldInt then
                        GwDebug(2, 'on_event: initiating reload.');
                        gwReloadHoldTime = time();
                        gwCommonChannel.configured = false;
                        gwOfficerChannel.configured = false;
                        GuildRoster();
                    end
                end
            
            end
        
        elseif chanNum == gwOfficerChannel.number then
        
            GwDebug(3, format('Rx<%d, %s>: %s', chanNum, sender, payload));
            
            local opcode, container, _, message = payload:match('^(%a)#(%w+)#([^#]*)#(.*)');
            
            if opcode == 'C' and sender ~= gwPlayerName and container ~= gwContainerId then

                GwReplicateMessage('OFFICER', sender, container, language, flags,
                        message, counter, guid);
        
            end
        
        end
        
    elseif event == 'CHAT_MSG_GUILD' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...);
        if sender == gwPlayerName then
            GwSendConfederationMsg(gwCommonChannel, 'chat', message);        
        end
    
    elseif event == 'CHAT_MSG_OFFICER' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...);
        if sender == gwPlayerName and GreenWall.ochat then
            GwSendConfederationMsg(gwOfficerChannel, 'chat', message);        
        end
    
    elseif event == 'CHAT_MSG_GUILD_ACHIEVEMENT' then
    
        local message, sender, _, _, _, flags, _, chanNum = select(1, ...);
        if sender == gwPlayerName then
            GwSendConfederationMsg(gwCommonChannel, 'achievement', message);
        end
    
    elseif event == 'CHAT_MSG_ADDON' then
    
        local prefix, message, dist, sender = select(1, ...);
        
        GwDebug(5, format('on_event: event=%s, prefix=%s, sender=%s, dist=%s, message=%s',
                event, prefix, sender, dist, message));
        
        GwDebug(3, format('Rx<ADDON(%s), %s>: %s', prefix, sender, message));
        
        if prefix == 'GreenWall' and dist == 'GUILD' and sender ~= gwPlayerName then
        
            local type, command = strsplit('#', message);
            
            GwDebug(5, format('on_event: type=%s, command=%s', type, command));
            
            if type == 'C' then
            
                if command == 'officer' then
                    if GwIsOfficer() then
                        -- Let 'em know you have the authoritay!
                        GwSendContainerMsg('response', 'officer');
                    end
                end
            
            elseif type == 'R' then
            
                if command == 'officer' then
                    if gwFlagOwner then
                        -- Verify the claim
                        if GwIsOfficer(sender) then
                            if gwCommonChannel.owner then
                                GwDebug(1, format('on_event: granting owner status to $s.', sender));
                                SetChannelOwner(gwCommonChannel.name, sender);
                            end
                            gwFlagHandoff = true;
                        end
                    end
                end
            
            end
            
        end
        
    elseif  event == 'CHANNEL_UI_UPDATE' then
    
        if gwGuildName ~= nil then
            GwRefreshComms();
        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE' then

        local action, _, _, _, _, _, type, number, name = select(1, ...);
        
        if number == gwCommonChannel.number then
            
            if action == 'YOU_LEFT' then
                gwCommonChannel.stats.disco = gwCommonChannel.stats.disco + 1;
                GwRefreshComms();
            end
        
        elseif number == gwOfficerChannel.number then
            
            if action == 'YOU_LEFT' then
                gwOfficerChannel.stats.disco = gwOfficerChannel.stats.disco + 1;
                GwRefreshComms();
            end
        
        elseif type == 1 then
        
            if action == 'YOU_JOINED' then
                GwDebug(2, 'on_event: General joined, unblocking reconnect.');
                gwFlagChatBlock = false;
                GwRefreshComms();
            end
                
        end

    elseif event == 'CHAT_MSG_SYSTEM' then

        local message = select(1, ...);
        
        GwDebug(5, format('on_event: system message: %s', message));
        
        local jpat = format(ERR_GUILD_JOIN_S, gwPlayerName);
        local lpat = format(ERR_GUILD_LEAVE_S, gwPlayerName);
        local rpat = format(ERR_GUILD_REMOVE_SS, '(.+)', gwPlayerName);
        local ppat = format(ERR_GUILD_PROMOTE_SSS, gwPlayerName, '(.+)', '(.+)'); 
        local dpat = format(ERR_GUILD_DEMOTE_SSS, gwPlayerName, '(.+)', '(.+)'); 
        
        if message:match(jpat) then

            -- We have joined the guild.
            GwDebug(1, 'on_event: guild join detected.');
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('join'));

        elseif message:match(lpat) then
        
            -- We have left the guild.
            GwDebug(1, 'on_event: guild quit detected.');
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('leave'));
            if GwIsConnected(gwCommonChannel) then
                GwLeaveChannel(gwCommonChannel);
                gwCommonChannel = GwNewChannelTable();
            end
            if GwIsConnected(gwOfficerChannel) then
                GwLeaveChannel(gwOfficerChannel);
                gwOfficerChannel = GwNewChannelTable();
            end

        elseif message:match(rpat) then
            
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('remove', message:match(rpat)));
        
        elseif message:match(ppat) then
            
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('promote', message:match(ppat)));
        
        elseif message:match(dpat) then
            
            GwSendConfederationMsg(gwCommonChannel, 'broadcast', GwEncodeBroadcast('demote', message:match(dpat)));
        
        end
        
    elseif event == 'GUILD_ROSTER_UPDATE' then
    
        gwGuildName = GetGuildInfo('Player');
        if gwGuildName == nil then
            GwDebug(2, 'guild_info: co-guild unavailable.');
            return false;
        else
            GwDebug(2, format('guild_info: co-guild is %s.', gwGuildName));
        end
            
        local timestamp = time();
        local holdtime = timestamp - gwConfigHoldTime;
        GwDebug(5, format('config_reload: common_conf=%s, officer_conf=%s, holdtime=%d, holdint=%d',
                tostring(gwCommonChannel.configured), tostring(gwOfficerChannel.configured), holdtime, gwConfigHoldInt));

        -- Update the configuration
        if not gwCommonChannel.configured then
            GwGetGuildInfoConfig(gwCommonChannel);
        end
        
        if GreenWall.ochat then
            if not gwOfficerChannel.configured then
                GwGetOfficerNoteConfig(gwOfficerChannel);
            end
        end
        
        -- Periodic check for updated configuration.
        if holdtime >= gwConfigHoldInt then
            GwGetGuildInfoConfig(gwCommonChannel);
            if GreenWall.ochat then
                GwGetOfficerNoteConfig(gwOfficerChannel);
            end
            gwConfigHoldTime = timestamp;
        end

        GwRefreshComms();

    elseif event == 'PLAYER_ENTERING_WORLD' then
    
        -- Added for 4.1
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix("GreenWall")
        end

    elseif event == 'PLAYER_GUILD_UPDATE' then
    
        -- Query the guild info.
        GuildRoster();
        
    elseif event == 'PLAYER_LOGIN' then

        -- Initiate the comms
        GwPrepComms();
        
        -- Defer joining to allow General to grab slot 1
        gwFlagChatBlock = true;
        
        -- Timer in case player has left General at some point
        gwChatBlockTimestamp = time() + gwChatBlockTimeout;
    
    end

    --
    -- Take care of our lazy timers
    --
    
    if gwFlagChatBlock then
        if gwChatBlockTimestamp <= time() then
            -- Give up
            GwDebug(2, 'on_event: reconnect deferral timeout expired.');
            gwFlagChatBlock = false;
            GwRefreshComms();
        end
    end

end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
