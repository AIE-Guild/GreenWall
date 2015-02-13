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


--[[-----------------------------------------------------------------------

Convenience Functions

--]]-----------------------------------------------------------------------

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
            gw.config:refreshChannels()
        end
    
    elseif command == 'reload' then
    
        gw.config.channel.guild:send(GW_MTYPE_REQUEST, 'reload')
        gw.Write('Broadcast configuration reload request.')
    
    elseif command == 'refresh' then
    
        gw.config:refresh()
        gw.config:refreshChannels()
        gw.Write('Refreshed configuration.')
    
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

    gw.Debug(GW_LOG_DEBUG, 'on_event: event=%s', event)

    --
    -- Addon loading check
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
        
        gw.Debug(GW_LOG_DEBUG, 'load_complete: name=%s, realm=%s', gw.player, gw.realm)
        
    end            
        
    if not gw.addon_loaded then
        return      -- early exit
    end

    --
    -- Main event switch
    --
    if event == 'CHAT_MSG_CHANNEL' then
    
        local chanNum = select(8, ...)
        
        if chanNum == gw.config.channel.guild.number then
            gw.config.channel.guild:receive(gw.handlerGuildChat, ...)
        elseif chanNum == gw.config.channel.officer.number then
            gw.config.channel.officer:receive(gw.handlerOfficerChat, ...)
        end
        
    elseif event == 'CHAT_MSG_GUILD' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%, message=%', event, sender, message)
        if gw.iCmp(sender, gw.player) then
            gw.config.channel.guild:send(GW_MTYPE_CHAT, message)
        end
    
    elseif event == 'CHAT_MSG_OFFICER' then
    
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%, message=%', event, sender, message)
        if gw.iCmp(sender, gw.player) and GreenWall.ochat then
            gw.config.channel.officer:send(GW_MTYPE_CHAT, message)
        end
    
    elseif event == 'CHAT_MSG_GUILD_ACHIEVEMENT' then
    
        local message, sender, _, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%, message=%', event, sender, message)
        if gw.iCmp(sender, gw.player) then
            gw.config.channel.guild:send(GW_MTYPE_ACHIEVEMENT, message)
        end
    
    elseif event == 'CHAT_MSG_CHANNEL_JOIN' then
    
        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, channel=%s, player=%s', event, number, player)
        
        if number == gw.config.channel.guild.number then
            if GetCVar('guildMemberNotify') == '1' and GreenWall.roster then
                if gw.config.comember_cache:hold(player) then
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: hit %s', player)
                else
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: miss %s', player)
                    GwReplicateMessage('SYSTEM', nil, nil, nil, nil, format(ERR_FRIEND_ONLINE_SS, player, player), nil, nil)
                end
            end
        end
    
    elseif event == 'CHAT_MSG_CHANNEL_LEAVE' then
    
        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, channel=%s, player=%s', event, number, player)
        
        if number == gw.config.channel.guild.number then
            if GetCVar('guildMemberNotify') == '1' and GreenWall.roster then
                if gw.config.comember_cache:hold(player) then
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: hit %s', player)
                else
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: miss %s', player)
                    GwReplicateMessage('SYSTEM', nil, nil, nil, nil, format(ERR_FRIEND_OFFLINE_S, player), nil, nil)
                end
            end
        end
                        
    elseif event == 'CHANNEL_UI_UPDATE' then
    
        if gw.GetGuildName() ~= nil then
            gw.config:refreshChannels()
        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE' then

        local action, _, _, _, _, _, type, number, name = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'chat_notice: type=%s, number=%s, name=%s, action=%s', type, number, name, action)
        
        if number == gw.config.channel.guild.number then
            
            if action == 'YOU_LEFT' then
                gw.config.channel.guild.stats.disco = gw.config.channel.guild.stats.disco + 1
                gw.config:refreshChannels()
            end
        
        elseif number == gw.config.channel.officer.number then
            
            if action == 'YOU_LEFT' then
                gw.config.channel.officer.stats.disco = gw.config.channel.officer.stats.disco + 1
                gw.config:refreshChannels()
            end
        
        elseif type == 1 then
        
            if action == 'YOU_JOINED' or action == 'YOU_CHANGED' then
                gw.Debug(GW_LOG_INFO, 'on_event: General joined, unblocking reconnect.')
                gw.config.timer.channel:clear()
                gw.config:refreshChannels()
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
            gw.config.comember_cache:hold(player)
            gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', player)
        
        elseif message:match(pat_offline) then
        
            local player = message:match(pat_offline)
            gw.Debug(GW_LOG_DEBUG, 'player_status: player %s offline', player)
            gw.config.comember_cache:hold(player)
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
    
        gw.config:load()
        gw.config:refreshChannels()

    elseif event == 'PLAYER_ENTERING_WORLD' then
    
        -- Added for 4.1
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix("GreenWall")
        end

    elseif event == 'PLAYER_GUILD_UPDATE' then
    
        -- Looks like our status has changed.
        gw.config:reset()
        
    elseif event == 'PLAYER_LOGIN' then

        -- Defer joining to allow General to grab slot 1
        gw.config.timer.channel:set()

        -- Initiate the comms
        gw.config:refresh()
        
    end
        
end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
