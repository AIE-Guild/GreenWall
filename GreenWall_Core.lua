--[[-----------------------------------------------------------------------

    $Id$

    $HeadURL$

    Copyright (c) 2010, 2011; Mark Rogaski.

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
  achievements
        -- Echo achievements from other co-guilds.
  tag
        -- Show co-guild identifier in messages.
  ochat
        -- Enable officer chat bridging.
  ochan <name> <password>
        -- Specify the officer channel name and password.
  debug <level>
        -- Set debugging level to integer <level>.
 
]];

--
-- Player variables
--

local gwPlayerName      = UnitName('Player');
local gwGuildName       = GetGuildInfo('Player'); 
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

local gwConfigString    = '';
local gwFlagChatBlock   = true;
local gwStateSendWho    = 0;
local gwAddonLoaded     = false;
local gwRosterUpdate    = false;


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
local gwTimeOutChatBlock    = 30;
local gwTimeStampChatBlock  = 0;

-- Holddown for reload requests
local gwHoldIntReload   = 180;
local gwHoldTimeReload  = 0;

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

--- Write a message to the default chat frame.
-- @param msg The message to send.
local function GwWrite(msg)

    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r ' .. msg);

end


--- Write an error message to the default chat frame.
-- @param msg The error message to send.
local function GwError(msg)

    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r |cffff6000[ERROR] ' .. msg);

end


--- Write a debugging message to the default chat frame with a detail level.
-- Messages will be filtered with the "/greenwall debug <level>" command.
-- @param level A positive integer specifying the debug level to display this under.
-- @param msg The message to send.
local function GwDebug(level, msg)

    if GreenWall ~= nil then
        if level <= GreenWall.debugLevel then
            DEFAULT_CHAT_FRAME:AddMessage(
                    format('|cffabd473GreenWall:|r |cff778899[DEBUG/%d] %s|r', level, msg));
        end
    end
    
end


--- Check if a connection exists to the common chat.
-- @param chan A channel control table.
-- @return True if connected, otherwise false.
local function GwIsConnected(chan)

    if chan.name ~= nil then
        chan.number = GetChannelName(chan.name);
        GwDebug(5, format('conn_check: chan_name=%s, chan_id=%d',
                chan.name, chan.number));
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
    
    GuildControlSetRank(rank);
    _, _, ochat = GuildControlGetRankFlags();
    
    if ochat then
        GwDebug(5, format('%s is rank %d and can see ochat', target, rank));
    else
        GwDebug(5, format('%s is rank %d and cannot see ochat', target, rank));
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
        static = false;
        dirty = false,
        owner = false,
        handoff = false,
        stats = {
            sconn = 0,
            fconn = 0,
            leave = 0,
            disco = 0
        }
    }
    return tab;
end


--- Reset all confederation configuration.
local function GwInitializeConfig()
    gwConfigString  = '';
    gwContainerId   = nil;
    gwPeerTable     = {};
    gwCommonChannel = GwNewChannelTable();
    gwOfficerChannel = GwNewChannelTable();
    gwStateSendWho  = 0;
    gwRosterUpdate  = false;
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
        if not GreenWall.achievements then
            return;
        end
        event = 'CHAT_MSG_GUILD_ACHIEVEMENT';
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
                    GwDebug(3, format('Tx<%s/%s, *, %s>: %s', frame, target, sender, message));
                    
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
-- @field chat Broadcast as a chat message.
-- @field achievement Broadcast as a chat message.
-- @field notice Informational, out-of-band message.
-- @field request Out-of-band request.
-- @param message Text of the message.
local function GwSendConfederationMsg(chan, type, message)

    GwDebug(5, format('conf_msg type=%s, message=%s', type, message));

    local opcode;
    
    if type == nil then
        GwDebug(2, 'missing arguments to GwSendConfederationMsg().');
        return;
    elseif type == 'chat' then
        opcode = 'C';
    elseif type == 'achievement' then
        opcode = 'A';
    elseif type == 'notice' then
        opcode = 'N';
    elseif type == 'request' then
        opcode = 'R';
    elseif type == 'addon' then
        opcode = 'M';
    else
        GwDebug(2, format('unknown message type: %s', type));
        return;
    end
    
    if message == nil then
        message = '';
    end
    
    if gwContainerId == nil then
        GwDebug(2, 'container ID not yet known, skipping GwSendConfederationMsg().');
        return;
    end
    
    local payload = strsub(strjoin('#', opcode, gwContainerId, '', message), 1, 255);
    GwDebug(3, format('Tx<%d, *, %s>: %s', chan.number, gwPlayerName, payload));
    SendChatMessage(payload , "CHANNEL", nil, chan.number); 

end


--- Sends an encoded message to the rest of the same container on the add-on channel.
-- @param type The message type.
-- @field request Command request.
-- @field response Command response.
-- @field info Informational message.
-- @param message Text of the message.
local function GwSendContainerMsg(type, message)

    GwDebug(5, format('cont_msg type=%s, message=%s', type, message));

    local opcode;
    
    if type == nil then
        GwDebug(2, 'missing arguments to GwSendContainerMsg().');
        return;
    elseif type == 'request' then
        opcode = 'C';
    elseif type == 'response' then
        opcode = 'R';
    elseif type == 'info' then
        opcode = 'I';
    else
        GwDebug(2, format('unknown message type: %s', type));
        return;
    end

    local payload = strsub(strjoin('#', opcode, message), 1, 255);
    GwDebug(3, format('Tx<ADDON/GUILD, *, %s>: %s', gwPlayerName, payload));
    SendAddonMessage('GreenWall', payload, 'GUILD');
    
end


--- Leave a shared confederation channel.
-- @param chan The channel control table.
local function GwLeaveChannel(chan)

    LeaveChannelByName(chan.name);
    GwDebug(1, format('left channel %s (%d)', chan.name, chan.number));
    chan.number = 0;
    chan.stats.leave = chan.stats.leave + 1;

end


--- Join the shared confederation channel.
-- @param chan the channel control block.
-- @return Integer channel number, 0 on failure.
local function GwJoinChannel(chan)

    if chan.name then
        --
        -- Open the communication link
        --
        JoinTemporaryChannel(chan.name, chan.password);
        chan.number = GetChannelName(chan.name);
        chan.dirty = false;
        
        if chan.number == 0 then

            GwError(format('cannot create communication channel: %s', chan.number));
            
            chan.stats.fconn = chan.stats.fconn + 1;
            
            return 0;

        else
        
            GwDebug(1, format('joined channel %s (%d)', chan.name, chan.number));
            GwWrite('Connected to confederation.');
            
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
                            GwDebug(2, format('hiding channel %s (%d) in %s', 
                                    chan.name, chan.number, frame));
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
        
        end
        
    end
    
    return chan.number;
    
end


--- Clear confederation configuration and request updated guild roster 
-- information from the server.
local function GwPrepComms()
    
    GwDebug(2, 'Initiating reconnect, querying guild roster.');
    
    if not GwIsConnected(gwCommonChannel) then
        GwInitializeConfig();
        if IsInGuild() then
            GuildRoster();
            gwRosterUpdate = true;
        end
    end
    
end


--- Parse the guild information page to gather configuration information.
-- @param chan Channel control table to update.
-- @return True if successful, false otherwise.
local function GwGetGuildInfoConfig(chan)

    GwDebug(2, 'parsing Guild Info.');

    local info = GetGuildInfoText();
    local update = false;
        
    if info == '' then

        GwDebug(2, 'Guild Info not yet available.');
        return false;
    
    else    

        -- Make sure we know which co-guild we are in.
        if gwGuildName == nil or gwGuildName == '' then
            gwGuildName = GetGuildInfo('Player');
            if gwGuildName == nil then
                return;
            end
        end
    
        -- We will rebuild the list of peer container guilds
        wipe(gwPeerTable);

        for buffer in gmatch(info, 'GW:([^\n]+)') do
        
            if buffer ~= nil then
                        
                buffer = strtrim(buffer);
                local vector = { strsplit(':', buffer) };
            
                if vector[1] == 'c' then
                
                    if vector[2] ~= chan.name then
                        GwDebug(2, "foo");
                        chan.name = vector[2];
                        chan.dirty = true;
                    end
                        
                    if vector[3] ~= chan.password then
                        GwDebug(2, "bar");
                        chan.password = vector[3];
                        chan.dirty = true;
                    end
                                        
                    GwDebug(2, format('channel: %s, password: %s', chan.name, chan.password));

                elseif vector[1] == 'o' then
                
                    local optlist = { strsplit(',', gsub(vector[2], '%s+', '')) };
                
                    for i, opt in ipairs(optlist) do
                    
                        local k, v = strsplit('=', opt);
                    
                        k = strlower(k);
                        v = strlower(v);
                        
                        if k == 'mv' then
                            if strmatch(v, '^%d+%.%d+%.%d+%w*$') then
                                gwOptMinVersion = v;
                                GwDebug(2, format('minimum version: %s', gwOptMinVersion));
                            end
                        elseif k == 'cd' then
                            if v == 'k' then
                                gwOptChanKick = true;
                                GwDebug(2, 'channel defense: kick');
                            elseif v == 'kb' then
                                gwOptChanBan = true;
                                GwDebug(2, 'channel defense: kick/ban');
                            else
                                GwDebug(2, 'channel defense: none');
                            end
                        end
                        
                    end
                                    
                elseif vector[1] == 'p' then
        
                    if vector[2] == gwGuildName then
                        gwContainerId = vector[3];
                        GwDebug(2, format('container: %s (%s)', gwGuildName, gwContainerId));
                    else 
                        gwPeerTable[vector[3]] = vector[2];
                        GwDebug(2, format('peer: %s (%s)', vector[2], vector[3]));
                    end
                    
                end
        
            end
    
        end
            
        GwWrite('Configuration updated.');
            
    end
        
    return true;
        
end


--- Parse the officer note of the guild leader to gather configuration information.
-- @param chan Channel control table to update.
-- @return True if successful, false otherwise.
local function GwGetOfficerNoteConfig(chan)

    -- Allow static configuration to override dynamic configuration
    if chan.static then
        return true;
    end
    
    -- Find the guild leader
    local n = GetNumGuildMembers();
    local leader = 0;
    local config = '';

    for i = 1, n do
        name, _, rank, _, _, _, _, note = GetGuildRosterInfo(i);
        if rank == 0 then
            GwDebug(2, format('parsing officer note for %s.', name));
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
        GwDebug(2, format('channel: %s, password: %s', chan.name, chan.password));
        return true;        
    end
    
end


--- Parse confederation configuration and connect to the common channel.
local function GwRefreshComms()

    GwDebug(2, 'refreshing communication channels.');

    if gwFlagChatBlock then
        GwDebug(2, 'Deferring comms refresh, General not yet joined.');
        return;
    end

    --
    -- Reconnect if necessary
    --
    if gwCommonChannel.dirty or not GwIsConnected(gwCommonChannel) then
        GwDebug(2, 'client not connected to common channel.');
        GwJoinChannel(gwCommonChannel);
    else
        GwDebug(2, 'client already connected to common channel.');
    end

    if gwOfficerChannel.dirty or not GwIsConnected(gwOfficerChannel) then
        if GreenWall.ochat then
            GwDebug(2, 'client not connected to officer channel.');
            GwJoinChannel(gwOfficerChannel);
        end
    else
        if GreenWall.ochat then
            GwDebug(2, 'client already connected to officer channel.');
        else
            GwDebug(2, 'disconnecting client from officer channel.');
            GwLeaveChannel(gwOfficerChannel);
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

local function GwSlashCmd(message, editbox)

    --
    -- Parse the command
    --
    local command, argstr = message:match('^(%S*)%s*(.*)');
    command = command:lower();
    
    GwDebug(4, format('command: %s, args: %s', command, argstr));
    
    if command == nil or command == '' or command == 'help' then
    
        for line in string.gmatch(gwUsage, '([^\n]*)\n') do
            GwWrite(line);
        end
    
    elseif command == 'achievements' then
    
        if GreenWall.achievements then
            GreenWall.achievements = false;
            GwWrite('co-guild achievements turned OFF.');
        else
            GreenWall.achievements = true;
            GwWrite('co-guild achievements turned ON.');
        end
    
    elseif command == 'debug' then
    
        local level = argstr:match('^(%d+)%s*$');
        if level ~= nil then
            GreenWall.debugLevel = level + 0; -- Lua typing stinks, gotta coerce an integer.
            GwWrite(format('Set debugging level to %d.', GreenWall.debugLevel));
        else
            GwWrite(format('Debugging level is %d', GreenWall.debugLevel));
        end
    
    elseif command == 'ochat' then
    
        if GreenWall.ochat then
            GreenWall.ochat = false;
            GwWrite('officer chat turned OFF.');
        else
            GreenWall.ochat = true;
            GwWrite('officer chat turned ON.');
        end
        GwRefreshComms();
        
    elseif command == 'ochan' then
    
        local ochan, opass = argstr:match('^(%S+)%s+(%S+)%s*$');
        gwOfficerChannel.name = oname;
        gwOfficerChannel.password = opass;
        gwOfficerChannel.static = true;
        GwWrite(format('Set officer chat channel to %s, password set to %s.', ochan, opass));
    
    elseif command == 'reload' then
    
        GwForceReload();
        GwWrite('Broadcast configuration reload request.');
    
    elseif command == 'refresh' then
    
        GwRefreshComms();
        GwWrite('Refreshed communication link.');
    
    elseif command == 'status' then
    
        GwWrite('container=' .. (gwContainerId == nil               and '<none>'    or gwContainerId));
        GwWrite(format('common: chan=%s(%d), pass=%s',
                (gwCommonChannel.name == nil        and '<none>'    or '[REDACTED]'), 
                (gwCommonChannel.number == nil      and 0           or gwCommonChannel.number), 
                (gwCommonChannel.password == nil    and '<none>'    or '[REDACTED]')
            ));
        GwWrite('connected='    .. (GwIsConnected(gwCommonChannel)  and 'yes'   or 'no'));
        GwWrite('chan_own='     .. (gwCommonChannel.owner           and 'yes'   or 'no'));

        if GreenWall.ochat then
            GwWrite(format('officer: chan=%s(%d), pass=%s',
                    (gwOfficerChannel.name == nil        and '<none>'    or '[REDACTED]'), 
                    (gwOfficerChannel.number == nil      and 0           or gwOfficerChannel.number), 
                    (gwOfficerChannel.password == nil    and '<none>'    or '[REDACTED]')
                ));
            GwWrite('connected='    .. (GwIsConnected(gwOfficerChannel)  and 'yes'   or 'no'));
            GwWrite('chan_own='     .. (gwOfficerChannel.owner           and 'yes'   or 'no'));
        end
        
        GwWrite('chan_kick='    .. (gwOptKick                       and 'yes'   or 'no'));
        GwWrite('chan_ban='     .. (gwOptBan                        and 'yes'   or 'no'));
        
        for i, v in pairs(gwPeerTable) do
            GwWrite(format('peer[%s] => %s', i, v));
        end
    
        GwWrite('version='      .. gwVersion);
        GwWrite('min_version='  .. gwOptMinVersion);
        GwWrite('achievements=' .. (GreenWall.achievements  and 'yes'   or 'no'));
        GwWrite('tag='          .. (GreenWall.tag           and 'yes'   or 'no'));
    
    elseif command == 'stats' then
    
        GwWrite(format('common: %d sconn, %d fconn, %d leave, %d disco', 
                gwCommonChannel.stats.sconn, gwCommonChannel.stats.fconn,
                gwCommonChannel.stats.leave, gwCommonChannel.stats.disco));
        if GreenWall.ochat then
            GwWrite(format('officer: %d sconn, %d fconn, %d leave, %d disco', 
                    gwOfficerChannel.stats.sconn, gwOfficerChannel.stats.fconn,
                    gwOfficerChannel.stats.leave, gwOfficerChannel.stats.disco));
        end
    
    elseif command == 'tag' then
    
        if GreenWall.tag then
            GreenWall.tag = false;
            GwWrite('co-guild tagging turned OFF.');
        else
            GreenWall.tag = true;
            GwWrite('co-guild tagging turned ON.');
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
    self:RegisterEvent('CHAT_MSG_CHANNEL_JOIN');
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE');
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE_USER');
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
            GreenWall = {
                version         = gwVersion,
                debugLevel      = 0,
                achievements    = false,
                tag             = false
            };
        end

        --
        -- Remedial configuration
        --
        GreenWall.version = gwVersion;
        if GreenWall.debugLevel == nil then
            GreenWall.debugLevel = 0;
        end
        
        if GreenWall.achievements == nil then
            GreenWall.achievements = false;
        end

        if GreenWall.tag == nil then
            GreenWall.tag = false;
        end
        
        if GreenWall.ochat == nil then
            GreenWall.ochat = false;
        end

        --
        -- Thundercats are go!
        --
        gwAddonLoaded = true;
        GwWrite(format('v%s loaded.', gwVersion));
        
    end            
        
    if gwAddonLoaded then
        GwDebug(4, format('event: %s', event));
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

                GwReplicateMessage('GUILD_ACHIEVEMENT', sender, container, language,
                        flags, message, counter, guid);

            elseif opcode == 'R' then
            
                --
                -- Incoming request
                --
                if message:match('^reload(%w.*)?$') then 
                    local diff = time() - gwHoldTimeReload;
                    GwWrite(format('Received configuration reload request from %s.', sender));
                    if diff >= gwHoldIntReload then
                        GwRefreshComms();
                        GwWrite('Refeshed communication link.');
                        gwHoldTimeReload = time();
                    end
                end
            
            end
        
        elseif chanNum == gwCommonChannel.number then
        
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
        
        GwDebug(5, format('event=%s, prefix=%s, sender=%s, dist=%s, message=%s',
                event, prefix, sender, dist, message));
        
        GwDebug(3, format('Rx<ADDON(%s), %s>: %s', prefix, sender, message));
        
        if prefix == 'GreenWall' and dist == 'GUILD' and sender ~= gwPlayerName then
        
            local type, command = strsplit('#', message);
            
            GwDebug(5, format('type=%s, command=%s', type, command));
            
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
                                GwDebug(1, format('Granting owner status to $s.', sender));
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
            if not GwIsConnected(gwCommonChannel) then
                GwRefreshComms();
            elseif GreenWall.ochat and not GwIsConnected(gwOfficerChannel) then
                GwRefreshComms();
            end
        end

    elseif event == 'CHAT_MSG_CHANNEL_JOIN' then
    
        local name = select(2, ...);
        local chanNum = select(8, ...);
        
        if chanNum == gwCommonChannel.number then

            --
            -- One of us?
            -- 
            if gwCommonChannel.owner and (gwOptChanKick or gwOptChanBan) then
                
                local guild = GetGuildInfo(name);
                
                if guild == nil then
                    
                    --
                    -- Query the server for the individual's guild
                    --
                    tinsert(gwGuildCheck, name);
                    SetWhoToUI(0);
                    SendWho(format('n-%s', name));
                
                else
                
                    --
                    -- Boot intruders
                    --
                    if not GwIsContainer(guild) then
                        if gwOptChanKick then
                            if gwOptChanBan then
                                ChannelBan(gwCommonChannel.name, name);
                            end
                            ChannelKick(gwCommonChannel.name, name);
                            GwSendConfederationMsg(gwCommonChannel, 'notice', 
                                    format('removed %s (%s), not in a co-guild.', name, guild));
                            GwDebug(1, 
                                    format('removed %s (%s), not in a co-guild.', name, guild));
                        end
                    end
                
                end
            
            end

        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE' then

        local action, _, _, _, _, _, type, number, name = select(1, ...);
        
        if number == gwCommonChannel.number then
            
            if action == 'YOU_LEFT' then
                gwCommonChannel.stats.disco = gwCommonChannel.stats.disco + 1;
                GwPrepComms();
            end
        
        elseif number == gwOfficerChannel.number then
            
            if action == 'YOU_LEFT' then
                gwOfficerChannel.stats.disco = gwOfficerChannel.stats.disco + 1;
                GwPrepComms();
            end
        
        elseif type == 1 then
        
            if action == 'YOU_JOINED' then
                GwDebug(2, 'General joined, unblocking reconnect.');
                gwFlagChatBlock = false;
                -- GwPrepComms();
            end
                
        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE_USER' then
    
        local message, target, _, _, actor, _, _, chanNum = select(1, ...);
    
        if chanNum == gwCommonChannel.number then
            
            GwDebug(5, format('event=%s, message=%s, target=%s, actor=%s, chanNum=%s',
                    event, message, target, actor, chanNum));
                            --
            -- Set the appropriate flags
            --

            if message == 'OWNER_CHANGED' or message == 'CHANNEL_OWNER' then

                if target == gwPlayerName then

                    gwCommonChannel.owner = true;
                
                    --[[
                    if not GwIsOfficer() then
                        -- Set a time to drop moderator status
                        gwHandoffTimer = time() + gwHandoffTimeout;
                        gwFlagHandoff = false;
                    end
                    ]]--

                    -- Query the members of the container guild for officers
                    GwSendContainerMsg('request', 'officer');

                else
                
                    gwCommonChannel.owner = false;

                end
            
            end
            
        end
        
    elseif event == 'CHAT_MSG_SYSTEM' then

        local message = select(1, ...);
        
        GwDebug(5, format('system message: %s', message));
        
        local name = string.match(message, '%[(.+)%]');
        local guild = string.match(message, '<(.+)>');

        if name ~= nil then

            if guild == nil then
                GwDebug(5, format('found %s in no guild', name));
            else
                GwDebug(5, format('found %s in guild %s', name, guild));
            end

            if tContains(gwGuildCheck, name) then

                --
                -- Boot if an intruder
                --
                if guild == nil or not GwIsContainer(guild) then
                    if gwOptChanKick then
                        if gwOptChanBan then
                            ChannelBan(gwCommonChannel.name, name);
                        end
                        ChannelKick(gwCommonChannel.name, name);
                        GwSendConfederationMsg(gwCommonChannel, 'notice', 
                                format('removed %s (%s), not in a co-guild.', name, guild));
                        GwDebug(1,
                                format('removed %s (%s), not in a co-guild.', name, guild));
                    end
                end

                --
                -- Clean up the table
                --
                local i = 1;
                while gwGuildCheck[i] do
                    if name == gwGuildCheck[i] then
                        tremove(gwGuildCheck, i);
                        break;
                    end
                end

            end

        end
        
    elseif event == 'GUILD_ROSTER_UPDATE' then
    
        if gwRosterUpdate then
            gwGuildName = GetGuildInfo('Player');
            if gwGuildName then
                if GwGetGuildInfoConfig(gwCommonChannel) and GwGetOfficerNoteConfig(gwOfficerChannel) then
                    gwRosterUpdate = false;
                end
                GwRefreshComms();
            end
        end

    elseif event == 'PLAYER_ENTERING_WORLD' then
    
        -- Added for 4.1
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix("GreenWall")
        end

    elseif event == 'PLAYER_GUILD_UPDATE' then
    
        if not IsInGuild() then
            -- Drop comms on quit or boot
            if  GwIsConnected(gwCommonChannel) then
                GwLeaveChannel(gwCommonChannel);
            end
        else
            -- Start the connection process otherwise
            GwPrepComms();
        end
        
    elseif event == 'PLAYER_LOGIN' then

        -- Initiate the comms
        GwPrepComms();
        
        -- Defer joining to allow General to grab slot 1
        gwFlagChatBlock = true;
        
        -- Timer in case player has left General at some point
        gwTimeStampChatBlock = time() + gwTimeOutChatBlock;
    
    end

    --
    -- Take care of our lazy timers
    --
    
    if gwFlagChatBlock then
        if gwTimeStampChatBlock <= time() then
            -- Give up
            GwDebug(2, 'Reconnect deferral timeout expired.');
            gwFlagChatBlock = false;
            GwPrepComms();
        end
    end

end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
