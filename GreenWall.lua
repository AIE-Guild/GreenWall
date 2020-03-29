--[[ -----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2020 Mark Rogaski

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

--[[ -----------------------------------------------------------------------

Imported Libraries

--]] -----------------------------------------------------------------------

local semver = LibStub:GetLibrary("SemanticVersion-1.0")


--
-- Kludge to avoid the MoP glyph bug
--
local _


--[[ -----------------------------------------------------------------------

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
        gw.Write('%s is set to %s.',
                gw.settings:getattr(key, 'desc'),
                tostring(gw.settings:get(key))
        )
    elseif gw.settings:getattr(key, 'type') == 'string' then
        if value and value ~= '' then
            gw.settings:set(key, value)
        end
        gw.Write('%s is set to %s.',
                gw.settings:getattr(key, 'desc'),
                gw.settings:get(key)
        )
    else
        gw.Error('cannot parse value for %s', key)
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

        gw.Write('GreenWall version %s.', gw.version)
        gw.Write('World of Warcraft version %s, build %s (%s), interface %s.',
                gw.build['version'], gw.build['number'], gw.build['date'], gw.build['interface'])

    else

        gw.Error('Unknown command: %s', command)
    end
end


--[[ -----------------------------------------------------------------------

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
    self:RegisterEvent('CHAT_MSG_CHANNEL')
    self:RegisterEvent('CHAT_MSG_CHANNEL_JOIN')
    self:RegisterEvent('CHAT_MSG_CHANNEL_LEAVE')
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE')
    self:RegisterEvent('CHAT_MSG_GUILD')
    self:RegisterEvent('CHAT_MSG_OFFICER')
    self:RegisterEvent('CHAT_MSG_SYSTEM')
    self:RegisterEvent('GUILD_ROSTER_UPDATE')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('PLAYER_GUILD_UPDATE')
    self:RegisterEvent('PLAYER_LOGIN')

    --
    -- Add a tab to the Interface Options panel.
    --
    self.name = 'GreenWall'
    self.refresh = function(self)
        GreenWallInterfaceFrame_OnShow(self)
    end
    self.okay = function(self)
        GreenWallInterfaceFrame_SaveUpdates(self)
    end
    self.cancel = function(self)
        return
    end
    self.default = function(self)
        GreenWallInterfaceFrame_SetDefaults(self)
    end
    InterfaceOptions_AddCategory(self)
end


--[[ -----------------------------------------------------------------------

Hooks

--]] -----------------------------------------------------------------------
function GreenWall_ParseText(chat, send)
    if (send == 1) then
        local chatType = chat:GetAttribute('chatType')
        local message = chat:GetText()
        gw.Debug(GW_LOG_DEBUG, 'type=%s, message=%q', chatType, message)
        if (message:match('%S')) then
            if gw.compatibility.name2chat then
                message = string.format('(%s) %s', Name2Chat.db.profile.name, message)
            end
            if gw.compatibility.identity then
                message = Identity2:AlterMessage(message, Identity2.db.profile.channels[chatType])
            end
            if (chatType == 'GUILD') then
                if gw.compatibility.incognito then
                    if Incognito.db.profile.enable and
                            Incognito.db.profile.name and
                            Incognito.db.profile.name ~= "" and
                            Incognito.db.profile.guild then
                        message = "(" .. Incognito.db.profile.name .. "): " .. message
                    end

                end
                gw.config.channel.guild:send(GW_MTYPE_CHAT, message)
            elseif (chatType == 'OFFICER') then
                gw.config.channel.officer:send(GW_MTYPE_CHAT, message)
            end
        end
    end
end

hooksecurefunc("ChatEdit_ParseText", GreenWall_ParseText)

--[[ -----------------------------------------------------------------------

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
        gw.settings = GwSettings:new()

        --
        -- Initialize the confederation configuration
        --
        gw.config = GwConfig:new()

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

        -- Messages will be forwarded by the ChatEdit_ParseText hook
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%s, message=%q', event, sender, message)

    elseif event == 'CHAT_MSG_OFFICER' then

        -- Messages will be forwarded by the ChatEdit_ParseText hook
        local message, sender, language, _, _, flags, _, chanNum = select(1, ...)
        gw.Debug(GW_LOG_DEBUG, 'event=%s, sender=%s, message=%q', event, sender, message)

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
        gw.Debug(GW_LOG_DEBUG, 'event=%s, message=%q', event, message)
        handler = GwSystemEventHandler:factory(gw.config, message)
        handler:run()

    elseif event == 'GUILD_ROSTER_UPDATE' then

        if gw.config:load() then
            gw.config:refresh_channels()
        end

    elseif event == 'PLAYER_ENTERING_WORLD' then

        C_ChatInfo.RegisterAddonMessagePrefix("GreenWall")
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
        gw.config.timer.channel:start(function()
            gw.config:refresh_channels()
        end)

        -- Initiate the comms
        gw.config:refresh()
    end
end


--[[ -----------------------------------------------------------------------

END

--]] -----------------------------------------------------------------------
