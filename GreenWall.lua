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


--
-- Kludge to avoid the MoP glyph bug
--
local _


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
-- Global objects
--
gw.config = GwConfig:new()


--
-- Cache tables
--
local gwComemberCache   = {}
local gwComemberTimeout = 180


--[[-----------------------------------------------------------------------

Convenience Functions

--]]-----------------------------------------------------------------------


--- Check if a connection exists to the common chat.
-- @param chan A channel control table.
-- @return True if connected, otherwise false.
local function GwIsConnected(chan)

    if chan.configured then
        chan.number = GetChannelName(chan.name)
        gw.Debug(GW_LOG_DEBUG, 'conn_check: chan_name=<<%04X>>, chan_id=%d', crc.Hash(chan.name), chan.number)
        if chan.number ~= 0 then
            return true
        end
    end
    
    return false
            
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

        gw.frame_table = { GetChatWindowMessages(i) }
        
        local v
        for _, v in ipairs(gw.frame_table) do
                        
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
    if gw.config.guild_id == nil then
        gw.Debug(GW_LOG_NOTICE, 'coguild_msg: missing container ID.')
        coguild = '-'
    else
        coguild = gw.config.guild_id
    end
    
    if message == nil then
        message = ''
    end
    
    -- Format the message.
    local payload = strsub(strjoin('#', opcode, coguild, '', message), 1, 255)
    
    -- Send the message.
    gw.Debug(GW_LOG_DEBUG, 'Tx<%d, %s>: %s', chan.number, gw.player, payload)
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
    gw.Debug(GW_LOG_DEBUG, 'Tx<ADDON/GUILD, *, %s>: %s', gw.player, payload)
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

    if chan.configured then
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
                gw.frame_table = { GetChatWindowMessages(i) }
                for j, v in ipairs(gw.frame_table) do
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
            if gw.IsOfficer() then
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
    gw.config:initialize()
    GuildRoster()
    
end


--- Parse confederation configuration and connect to the common channel.
local function GwRefreshComms()

    gw.Debug(GW_LOG_INFO, 'refresh_comms: refreshing communication channels.')

    --
    -- Connect if necessary
    --
    if GwIsConnected(gw.config.channel.guild) then    
        if gw.config.channel.guild.dirty then
            gw.Debug(GW_LOG_INFO, 'refresh_comms: common channel dirty flag set.')
            GwLeaveChannel(gw.config.channel.guild)
            if GwJoinChannel(gw.config.channel.guild) then
                GwFlushChannel(gw.config.channel.guild)
            end
            gw.config.channel.guild.dirty = false
        end
    elseif gw.config.timer.channel:hold() then
        gw.Debug(GW_LOG_INFO, 'refresh_comms: deferring common channel refresh, General not yet joined.')
    else    
        if GwJoinChannel(gw.config.channel.guild) then
            GwFlushChannel(gw.config.channel.guild)
        end
    end

    if GreenWall.ochat then
        if GwIsConnected(gw.config.channel.officer) then    
            if gw.config.channel.officer.dirty then
                gw.Debug(GW_LOG_INFO, 'refresh_comms: officer channel dirty flag set.')
                GwLeaveChannel(gw.config.channel.officer)
                if GwJoinChannel(gw.config.channel.officer) then
                    GwFlushChannel(gw.config.channel.officer)
                end
                gw.config.channel.officer.dirty = false
            end
        elseif gw.config.timer.channel:hold() then
            gw.Debug(GW_LOG_INFO, 'refresh_comms: deferring officer channel refresh, General not yet joined.')
        else    
            if GwJoinChannel(gw.config.channel.officer) then
                GwFlushChannel(gw.config.channel.officer)
            end
        end
    end

end


--- Send a configuration reload request to the rest of the confederation.
local function GwForceReload()
    if GwIsConnected(gw.config.channel.guild) then
        GwSendConfederationMsg(gw.config.channel.guild, 'request', 'reload')
    end 
end


--[[-----------------------------------------------------------------------

UI Handlers

--]]-----------------------------------------------------------------------

function GreenWallInterfaceFrame_OnShow(self)
    if (not gw.addon_loaded) then
        -- Configuration not loaded.
        self:Hide()
        return
    end
    
    -- Populate interface panel.
    getglobal(self:GetName().."OptionTag"):SetChecked(GreenWall.tag)
    getglobal(self:GetName().."OptionAchievements"):SetChecked(GreenWall.achievements)
    getglobal(self:GetName().."OptionRoster"):SetChecked(GreenWall.roster)
    getglobal(self:GetName().."OptionRank"):SetChecked(GreenWall.rank)
    if (gw.IsOfficer()) then
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
    if (gw.IsOfficer()) then
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
            gw.config:load()
            GwRefreshComms()
        end
    
    elseif command == 'reload' then
    
        GwForceReload()
        gw.Write('Broadcast configuration reload request.')
    
    elseif command == 'refresh' then
    
        GwRefreshComms()
        gw.Write('Refreshed communication link.')
    
    elseif command == 'status' then
    
        gw.config:dump()
    
    elseif command == 'stats' then
    
        gw.Write('common: %d sconn, %d fconn, %d leave, %d disco', 
                gw.config.channel.guild.stats.sconn, gw.config.channel.guild.stats.fconn,
                gw.config.channel.guild.stats.leave, gw.config.channel.guild.stats.disco)
        if GreenWall.ochat then
            gw.Write('officer: %d sconn, %d fconn, %d leave, %d disco', 
                    gw.config.channel.officer.stats.sconn, gw.config.channel.officer.stats.fconn,
                    gw.config.channel.officer.stats.leave, gw.config.channel.officer.stats.disco)
        end
    
    elseif command == 'version' then

        gw.Write('GreenWall version %s.', gw.version)

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
    self.name = 'GreenWall ' .. gw.version
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
    GreenWall.version = gw.version

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
        gw.addon_loaded = true
        gw.Write('v%s loaded.', gw.version)
        
        gw.Debug(GW_LOG_DEBUG, 'init: name=%s, realm=%s', gw.player, gw.realm)
        
    end            
        
    if gw.addon_loaded then
        gw.Debug(GW_LOG_DEBUG, 'on_event: event=%s', event)
    else
        return      -- early exit
    end

    local timestamp = time()

    if event == 'CHAT_MSG_CHANNEL' then
    
        local payload, sender, language, _, _, flags, _, 
                chanNum, _, _, counter, guid = select(1, ...)
        
        if chanNum == gw.config.channel.guild.number or chanNum == gw.config.channel.officer.number then
        
            sender = gw.GlobalName(sender)   -- Groom sender name.
        
            gw.Debug(GW_LOG_DEBUG, 'Rx<%d, %d, %s>: %s', chanNum, counter, sender, payload)
            gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gw.player)

            local opcode, container, _, message = strsplit('#', payload, 4)
            
            if opcode == nil or container == nil or message == nil then
            
                gw.Debug(GW_LOG_NOTICE, 'rx_validation: invalid message format.')
                
            else
            
                if opcode == 'R' then
                
                    --
                    -- Incoming request
                    --
                    if message == 'reload' then
                        gw.Write('Received configuration reload request from %s.', sender)
                        if not gw.config.timer.reload:hold() then
                            gw.Debug(GW_LOG_INFO, 'on_event: initiating reload.')
                            gw.config.channel.guild.configured = false
                            gw.config.channel.officer.configured = false
                            gw.config.timer.reload:set()
                            GuildRoster()
                        end
                    end
        
                elseif not gw.iCmp(sender, gw.player) and container ~= gw.config.guild_id then
                
                    if opcode == 'C' then
        
                        if chanNum == gw.config.channel.guild.number then
                            GwReplicateMessage('GUILD', sender, container, language, flags, message, counter, guid)
                        elseif chanNum == gw.config.channel.officer.number then
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
            if gw.iCmp(sender, gw.player) then                
            
                local tx_hash = nil
                if chanNum == gw.config.channel.guild.number then
                    tx_hash = gw.config.channel.guild.tx_hash
                elseif chanNum == gw.config.channel.officer.number then
                    tx_hash = gw.config.channel.officer.tx_hash
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
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gw.player)
        if gw.iCmp(sender, gw.player) then
            GwSendConfederationMsg(gw.config.channel.guild, 'chat', message)
        end
    
    elseif event == 'CHAT_MSG_OFFICER' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'Rx<OFFICER, %s>: %s', sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gw.player)
        if gw.iCmp(sender, gw.player) and GreenWall.ochat then
            GwSendConfederationMsg(gw.config.channel.officer, 'chat', message)
        end
    
    elseif event == 'CHAT_MSG_GUILD_ACHIEVEMENT' then
    
        local message, sender, _, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'Rx<ACHIEVEMENT, %s>: %s', sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gw.player)
        if gw.iCmp(sender, gw.player) then
            GwSendConfederationMsg(gw.config.channel.guild, 'achievement', message)
        end
    
    elseif event == 'CHAT_MSG_ADDON' then
    
        local prefix, message, dist, sender = select(1, ...)
        
        gw.Debug(GW_LOG_DEBUG, 'on_event: event=%s, prefix=%s, sender=%s, dist=%s, message=%s',
                event, prefix, sender, dist, message)
        gw.Debug(GW_LOG_DEBUG, 'Rx<ADDON(%s), %s>: %s', prefix, sender, message)
        gw.Debug(GW_LOG_DEBUG, 'sender_info: sender=%s, id=%s', sender, gw.player)
        
        if prefix == 'GreenWall' and dist == 'GUILD' and not gw.iCmp(sender, gw.player) then
        
            local type, command = strsplit('#', message)
            
            gw.Debug(GW_LOG_DEBUG, 'on_event: type=%s, command=%s', type, command)
            
            if type == 'C' then
            
                if command == 'officer' then
                    if gw.IsOfficer() then
                        -- Let 'em know you have the authoritay!
                        GwSendContainerMsg('response', 'officer')
                    end
                end
            
            elseif type == 'R' then
            
                if command == 'officer' then
                    if gwFlagOwner then
                        -- Verify the claim
                        if gw.IsOfficer(sender) then
                            if gw.config.channel.guild.owner then
                                gw.Debug(GW_LOG_INFO, 'on_event: granting owner status to $s.', sender)
                                SetChannelOwner(gw.config.channel.guild.name, sender)
                            end
                        end
                    end
                end
            
            end
            
        end
        
    elseif event == 'CHAT_MSG_CHANNEL_JOIN' then
    
        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'chan_join: channel=%s, player=%s', number, player)
        
        if number == gw.config.channel.guild.number then
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
        
        if number == gw.config.channel.guild.number then
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
    
        if gw.GetGuildName() ~= nil then
            GwRefreshComms()
        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE' then

        local action, _, _, _, _, _, type, number, name = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'chat_notice: type=%s, number=%s, name=%s, action=%s', type, number, name, action)
        
        if number == gw.config.channel.guild.number then
            
            if action == 'YOU_LEFT' then
                gw.config.channel.guild.stats.disco = gw.config.channel.guild.stats.disco + 1
                GwRefreshComms()
            end
        
        elseif number == gw.config.channel.officer.number then
            
            if action == 'YOU_LEFT' then
                gw.config.channel.officer.stats.disco = gw.config.channel.officer.stats.disco + 1
                GwRefreshComms()
            end
        
        elseif type == 1 then
        
            if action == 'YOU_JOINED' or action == 'YOU_CHANGED' then
                gw.Debug(GW_LOG_INFO, 'on_event: General joined, unblocking reconnect.')
                gw.config.timer.channel:clear()
                GwRefreshComms()
            end
                
        end

    elseif event == 'CHAT_MSG_SYSTEM' then

        local message = select(1, ...)
        
        gw.Debug(GW_LOG_DEBUG, 'on_event: system message: %s', message)
        
        local pat_online = string.gsub(format(ERR_FRIEND_ONLINE_SS, '(.+)', '(.+)'), '%[', '%%[')
        local pat_offline = format(ERR_FRIEND_OFFLINE_S, '(.+)')
        local pat_join = format(ERR_GUILD_JOIN_S, gw.player)
        local pat_leave = format(ERR_GUILD_LEAVE_S, gw.player)
        local pat_quit = format(ERR_GUILD_QUIT_S, gw.player)
        local pat_removed = format(ERR_GUILD_REMOVE_SS, gw.player, '(.+)')
        local pat_kick = format(ERR_GUILD_REMOVE_SS, '(.+)', gw.player)
        local pat_promote = format(ERR_GUILD_PROMOTE_SSS, gw.player, '(.+)', '(.+)')
        local pat_demote = format(ERR_GUILD_DEMOTE_SSS, gw.player, '(.+)', '(.+)')
        
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
            GwSendConfederationMsg(gw.config.channel.guild, 'broadcast', GwEncodeBroadcast('join'))

        elseif message:match(pat_leave) or message:match(pat_quit) or message:match(pat_removed) then
        
            -- We have left the guild.
            gw.Debug(GW_LOG_DEBUG, 'on_event: guild quit detected.')
            GwSendConfederationMsg(gw.config.channel.guild, 'broadcast', GwEncodeBroadcast('leave'))
            if GwIsConnected(gw.config.channel.guild) then
                GwAbandonChannel(gw.config.channel.guild)
                gw.config.channel.guild = GwNewChannelTable()
            end
            if GwIsConnected(gw.config.channel.officer) then
                GwAbandonChannel(gw.config.channel.officer)
                gw.config.channel.officer = GwNewChannelTable()
            end

        elseif message:match(pat_kick) then
            
            GwSendConfederationMsg(gw.config.channel.guild, 'broadcast', GwEncodeBroadcast('remove', message:match(pat_kick)))
        
        elseif message:match(pat_promote) then
            
            GwSendConfederationMsg(gw.config.channel.guild, 'broadcast', GwEncodeBroadcast('promote', message:match(pat_promote)))
        
        elseif message:match(pat_demote) then
            
            GwSendConfederationMsg(gw.config.channel.guild, 'broadcast', GwEncodeBroadcast('demote', message:match(pat_demote)))
        
        end

    elseif event == 'GUILD_ROSTER_UPDATE' then
    
        local guild = gw.GetGuildName()
        if guild == nil then

            gw.Debug(GW_LOG_NOTICE, 'guild_info: co-guild unavailable.')
            
        else
            gw.Debug(GW_LOG_DEBUG, 'guild_info: co-guild is %s.', guild)
            
            -- Update the configuration
            if not gw.config.loaded then
                gw.config:load()
            end
                    
            GwRefreshComms()
            
        end

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
        gw.config.timer.channel:set()

    end

    --
    -- Take care of our lazy timers
    --
    
    if gw.config.timer.channel:hold() then
        GwRefreshComms()
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
