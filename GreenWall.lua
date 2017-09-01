--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2017 Mark Rogaski

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

--[[-----------------------------------------------------------------------

Imported Libraries

--]] -----------------------------------------------------------------------

local crc = LibStub:GetLibrary("Hash:CRC:16ccitt-1.0")


--
-- Kludge to avoid the MoP glyph bug
--
local _


--
-- Global objects
--
gw.config = GwConfig:new()


--[[-----------------------------------------------------------------------

UI Handlers

--]] -----------------------------------------------------------------------
function GreenWallInterfaceFrame_OnShow(self)
    if (not gw.addon_loaded) then
        -- Configuration not loaded.
        self:Hide()
        return
    end

    -- Initialize widgets
    getglobal(self:GetName() .. "OptionJoinDelay"):SetMinMaxValues(gw.settings:getattr('joindelay', 'min'),
        gw.settings:getattr('joindelay', 'max'))
    getglobal(self:GetName() .. "OptionJoinDelay"):SetValueStep(gw.settings:getattr('joindelay', 'step'))

    -- Populate interface panel.
    getglobal(self:GetName() .. "OptionTag"):SetChecked(gw.settings:get('tag'))
    getglobal(self:GetName() .. "OptionAchievements"):SetChecked(gw.settings:get('achievements'))
    getglobal(self:GetName() .. "OptionRoster"):SetChecked(gw.settings:get('roster'))
    getglobal(self:GetName() .. "OptionRank"):SetChecked(gw.settings:get('rank'))
    getglobal(self:GetName() .. "OptionJoinDelay"):SetValue(gw.settings:get('joindelay'))
    if (gw.IsOfficer()) then
        getglobal(self:GetName() .. "OptionOfficerChat"):SetChecked(gw.settings:get('ochat'))
        getglobal(self:GetName() .. "OptionOfficerChatText"):SetTextColor(1, 1, 1)
        getglobal(self:GetName() .. "OptionOfficerChat"):Enable()
    else
        getglobal(self:GetName() .. "OptionOfficerChat"):SetChecked(false)
        getglobal(self:GetName() .. "OptionOfficerChatText"):SetTextColor(.5, .5, .5)
        getglobal(self:GetName() .. "OptionOfficerChat"):Disable()
    end
end

function GreenWallInterfaceFrame_SaveUpdates(self)
    gw.settings:set('tag', getglobal(self:GetName() .. "OptionTag"):GetChecked() and true or false)
    gw.settings:set('achievements', getglobal(self:GetName() .. "OptionAchievements"):GetChecked() and true or false)
    gw.settings:set('roster', getglobal(self:GetName() .. "OptionRoster"):GetChecked() and true or false)
    gw.settings:set('rank', getglobal(self:GetName() .. "OptionRank"):GetChecked() and true or false)
    gw.settings:set('joindelay', getglobal(self:GetName() .. "OptionJoinDelay"):GetValue())
    if (gw.IsOfficer()) then
        gw.settings:set('ochat', getglobal(self:GetName() .. "OptionOfficerChat"):GetChecked() and true or false)
    end
end

function GreenWallInterfaceFrame_SetDefaults(self)
    gw.settings:reset()
end

function GreenWallInterfaceFrameOptionJoinDelay_OnValueChanged(self, value)
    -- Fix for 5.4.0, see http://www.wowwiki.com/Patch_5.4.0/API_changes
    if not self._onsetting then
        self._onsetting = true
        self:SetValue(self:GetValue())
        value = self:GetValue()
        self._onsetting = false
    else return
    end
    getglobal(self:GetName() .. "Text"):SetText(value)
end

--[[-----------------------------------------------------------------------

Slash Command Handler

--]] -----------------------------------------------------------------------

--- Update or display the value of a user settings variable.
-- @param key The name of the variable.
-- @param value The variable value.
local function GwSettingCmd(key, value)
    if gw.settings:getattr(key, 'type') == 'boolean' then
        if value and value ~= '' then
            if value == 'on' then
                gw.settings:set(key, true)
            elseif value == 'off' then
                gw.settings:set(key, false)
            else
                gw.Error('%s setting must be "on" or "off"', key)
            end
        end
        gw.Write('%s is turned %s.',
            gw.settings:getattr(key, 'desc'),
            gw.settings:get(key) and 'ON' or 'OFF'
        )
    elseif gw.settings:getattr(key, 'type') == 'number' then
        if value and value ~= '' then
            if value:match('^-?%d+$') then
                gw.settings:set(key, value + 0)
            else
                gw.Error('%s setting must be numeric: %s', key)
            end
        end
        gw.Write('%s is set to %d.',
            gw.settings:getattr(key, 'desc'),
            gw.settings:get(key)
        )
    end
end


local function GwSlashCmd(message, editbox)

    --
    -- Parse the command
    --
    local command, argstr = message:match('^(%S*)%s*(%S*)%s*')
    command = command:lower()

    gw.Debug(GW_LOG_NOTICE, 'command=%s, args=%s', command, argstr)

    if command == nil or command == '' or command == 'help' then

        for line in string.gmatch(gw.usage, '([^\n]*)\n') do
            gw.Write(line)
        end

    elseif gw.settings:exists(command) then

        GwSettingCmd(command, argstr)

    elseif command == 'admin' then

        if gw.IsOfficer() then
            if argstr == 'reload' then
                gw.SendLocal(GW_MTYPE_CONTROL, 'reload')
                gw.Write('Broadcast configuration reload request.')
            end
        else
            gw.Error('The admin command may only be issued by an officer.')
        end

    elseif command == 'reload' or command == 'refresh' then

        gw.Write('Reloading configuration.')
        gw.config:reload()

    elseif command == 'reset' then

        gw.Write('Resetting configuration.')
        gw.config:reset()

    elseif command == 'dump' then

        gw.config:dump()

    elseif command == 'status' then

        gw.config:dump_status()

    elseif command == 'version' then

        local version, build, _, interface = GetBuildInfo()
        gw.Write('GreenWall version %s.', gw.version)
        gw.Write('World of Warcraft version %s, build %s, interface %s.',
            version, build, interface)

    else

        gw.Error('Unknown command: %s', command)
    end
end


--[[-----------------------------------------------------------------------

Initialization

--]] -----------------------------------------------------------------------
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
    self:RegisterEvent('CHAT_MSG_LOOT')
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
    self.name = 'GreenWall'
    self.refresh = function(self) GreenWallInterfaceFrame_OnShow(self) end
    self.okay = function(self) GreenWallInterfaceFrame_SaveUpdates(self) end
    self.cancel = function(self) return end
    self.default = function(self) GreenWallInterfaceFrame_SetDefaults(self) end
    InterfaceOptions_AddCategory(self)
end


--[[-----------------------------------------------------------------------

Frame Event Functions

--]] -----------------------------------------------------------------------
function GreenWall_OnEvent(self, event, ...)

    gw.Debug(GW_LOG_DEBUG, 'event occurred; event=%s', event)

    --
    -- Addon loading check
    --
    if event == 'ADDON_LOADED' and select(1, ...) == 'GreenWall' then

        --
        -- Initialize the saved variables
        --
        -- GwSetDefaults(true)
        gw.settings = GwSettings:new()

        --
        -- Thundercats are go!
        --
        gw.addon_loaded = true
        gw.Write('v%s loaded.', gw.version)
        gw.Debug(GW_LOG_DEBUG, 'loading complete; name=%s, realm=%s', gw.player, gw.realm)
    end

    if not gw.addon_loaded then
        return -- early exit
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
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%s, message=%s', event, sender, message)
        if gw.iCmp(sender, gw.player) then
            gw.config.channel.guild:send(GW_MTYPE_CHAT, message)
        end

    elseif event == 'CHAT_MSG_LOOT' then

        local message, sender, _, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%s, message=%s', event, sender, message)
        item = gw.GetItemString(message)
        if gw.IsLegendary(item) then
            if gw.iCmp(sender, gw.player) then
                gw.config.channel.guild:send(GW_MTYPE_LOOT, message)
            end
        end

    elseif event == 'CHAT_MSG_OFFICER' then

        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%s, message=%s', event, sender, message)
        if gw.iCmp(sender, gw.player) and gw.settings:get('ochat') then
            gw.config.channel.officer:send(GW_MTYPE_CHAT, message)
        end

    elseif event == 'CHAT_MSG_ADDON' then

        local prefix, payload, dist, sender = select(1, ...)
        if prefix == 'GreenWall' and dist == 'GUILD' then
            gw.ReceiveLocal(sender, payload)
        end

    elseif event == 'CHAT_MSG_GUILD_ACHIEVEMENT' then

        local message, sender, _, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%s, message=%s', event, sender, message)
        if gw.iCmp(sender, gw.player) then
            gw.config.channel.guild:send(GW_MTYPE_ACHIEVEMENT, message)
        end

    elseif event == 'CHAT_MSG_CHANNEL_JOIN' then

        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, channel=%s, player=%s', event, number, player)

        if number == gw.config.channel.guild.number then
            if GetCVar('guildMemberNotify') == '1' and gw.settings:get('roster') then
                if gw.config.comember_cache:hold(gw.GlobalName(player)) then
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: hit %s', gw.GlobalName(player))
                else
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: miss %s', gw.GlobalName(player))
                    gw.ReplicateMessage('SYSTEM', format(ERR_FRIEND_ONLINE_SS, player, player))
                end
            end
        end

    elseif event == 'CHAT_MSG_CHANNEL_LEAVE' then

        local _, player, _, _, _, _, _, number = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, channel=%s, player=%s', event, number, player)

        if number == gw.config.channel.guild.number then
            if GetCVar('guildMemberNotify') == '1' and gw.settings:get('roster') then
                if gw.config.comember_cache:hold(gw.GlobalName(player)) then
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: hit %s', gw.GlobalName(player))
                else
                    gw.Debug(GW_LOG_DEBUG, 'comember_cache: miss %s', gw.GlobalName(player))
                    gw.ReplicateMessage('SYSTEM', format(ERR_FRIEND_OFFLINE_S, player))
                end
            end
        end

    elseif event == 'CHANNEL_UI_UPDATE' then

        if gw.GetGuildName() ~= nil then
            gw.config:refresh_channels()
        end

        if gw.config.timer.channel:hold() then
            for _, v in ipairs({ GetChannelList() }) do
                if v == 'General' then
                    gw.config.timer.channel:clear()
                end
            end
        end

    elseif event == 'CHAT_MSG_CHANNEL_NOTICE' then

        local action, _, _, _, _, _, type, number, name = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, type=%s, number=%s, name=%s, action=%s', event, type, number, gw.Redact(tostring(name)), action)

        if number == gw.config.channel.guild.number then

            if action == 'YOU_LEFT' then
                gw.config.channel.guild.stats.disco = gw.config.channel.guild.stats.disco + 1
                gw.config:refresh_channels()
            end

        elseif number == gw.config.channel.officer.number then

            if action == 'YOU_LEFT' then
                gw.config.channel.officer.stats.disco = gw.config.channel.officer.stats.disco + 1
                gw.config:refresh_channels()
            end

        elseif type == 1 then

            if action == 'YOU_JOINED' or action == 'YOU_CHANGED' then
                gw.Debug(GW_LOG_NOTICE, 'world channel joined, unblocking reconnect.')
                gw.config.timer.channel:clear()
                gw.config:refresh_channels()
            end
        end

    elseif event == 'CHAT_MSG_SYSTEM' then

        local message = select(1, ...)

        gw.Debug(GW_LOG_DEBUG, 'event=%s, message=%s', event, message)

        local pat_online = string.gsub(format(ERR_FRIEND_ONLINE_SS, '(.+)', '(.+)'), '%[', '%%[')
        local pat_offline = format(ERR_FRIEND_OFFLINE_S, '(.+)')
        local pat_join = format(ERR_GUILD_JOIN_S, '(.+)')
        local pat_leave = format(ERR_GUILD_LEAVE_S, '(.+)')
        local pat_quit = format(ERR_GUILD_QUIT_S, gw.player)
        local pat_removed = format(ERR_GUILD_REMOVE_SS, '(.+)', '(.+)')
        local pat_kick = format(ERR_GUILD_REMOVE_SS, '(.+)', '(.+)')
        local pat_promote = format(ERR_GUILD_PROMOTE_SSS, '(.+)', '(.+)', '(.+)')
        local pat_demote = format(ERR_GUILD_DEMOTE_SSS, '(.+)', '(.+)', '(.+)')

        if message:match(pat_online) then

            local _, player = message:match(pat_online)
            player = gw.GlobalName(player)
            gw.config.comember_cache:hold(player)
            gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', player)

        elseif message:match(pat_offline) then

            local player = message:match(pat_offline)
            player = gw.GlobalName(player)
            gw.config.comember_cache:hold(player)
            gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', player)

        elseif message:match(pat_join) then

            local player = message:match(pat_join)
            if gw.GlobalName(player) == gw.player then
                -- We have joined the guild.
                gw.Debug(GW_LOG_NOTICE, 'guild join detected.')
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'join')
            end

        elseif message:match(pat_leave) then

            local player = message:match(pat_leave)
            if gw.GlobalName(player) == gw.player then
                -- We have left the guild.
                gw.Debug(GW_LOG_NOTICE, 'guild quit detected.')
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'leave')
                gw.config:reset()
            end

        elseif message:match(pat_quit) then

            local player = message:match(pat_quit)
            if gw.GlobalName(player) == gw.player then
                -- We have left the guild.
                gw.Debug(GW_LOG_NOTICE, 'guild quit detected.')
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'leave')
                gw.config:reset()
            end

        elseif message:match(pat_removed) then

            local player = message:match(pat_removed)
            if gw.GlobalName(player) == gw.player then
                -- We have been kicked from the guild.
                gw.Debug(GW_LOG_NOTICE, 'guild kick detected.')
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'leave')
                gw.config:reset()
            end

        elseif message:match(pat_kick) then

            local target, player = message:match(pat_kick)
            if gw.GlobalName(player) == gw.player then
                gw.Debug(GW_LOG_NOTICE, 'you kicked %s', target)
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'remove', target)
            end

        elseif message:match(pat_promote) then

            local player, target, rank = message:match(pat_promote)
            if gw.GlobalName(player) == gw.player then
                gw.Debug(GW_LOG_NOTICE, 'you promoted %s to %s', target, rank)
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'promote', target, rank)
            end

        elseif message:match(pat_demote) then

            local player, target, rank = message:match(pat_demote)
            if gw.GlobalName(player) == gw.player then
                gw.Debug(GW_LOG_NOTICE, 'you demoted %s to %s', target, rank)
                gw.config.channel.guild:send(GW_MTYPE_BROADCAST, 'demote', target, rank)
            end
        end

    elseif event == 'GUILD_ROSTER_UPDATE' then

        if gw.config:load() then
            gw.config:refresh_channels()
        end

    elseif event == 'PLAYER_ENTERING_WORLD' then

        -- Added for 4.1
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix("GreenWall")
        end

        -- Apply compatibility workarounds
        gw.EnableCompatibility()


    elseif event == 'PLAYER_GUILD_UPDATE' then

        local new_status = gw.GetGuildStatus()
        if gw.guild_status ~= new_status then
            -- Looks like our status has changed.
            gw.config:reset()
            gw.guild_status = new_status
        end

    elseif event == 'PLAYER_LOGIN' then

        -- Defer joining to allow General to grab slot 1
        gw.config.timer.channel:start(function() gw.config:refresh_channels() end)

        -- Initiate the comms
        gw.config:refresh()
    end
end


--[[-----------------------------------------------------------------------

END

--]] -----------------------------------------------------------------------
