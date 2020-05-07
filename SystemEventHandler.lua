--[[-----------------------------------------------------------------------

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

--]]-----------------------------------------------------------------------

local pat_online = ERR_FRIEND_ONLINE_SS:format('(.+)', '(.+)'):gsub('([%[%]])', '%%%1')
local pat_online_raw = "(.+) has come online."
local pat_offline = ERR_FRIEND_OFFLINE_S:format('(.+)')
local pat_join = ERR_GUILD_JOIN_S:format('(.+)')
local pat_leave = ERR_GUILD_LEAVE_S:format('(.+)')
local pat_quit = ERR_GUILD_QUIT_S:format('(.+)')
local pat_removed = ERR_GUILD_REMOVE_SS:format('(.+)', '(.+)')
local pat_kick = ERR_GUILD_REMOVE_SELF

GwSystemEventHandler = { config = nil, player = nil }

function GwSystemEventHandler:new(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function GwSystemEventHandler:run()
end

GwOnlineSystemEventHandler = GwSystemEventHandler:new()

function GwOnlineSystemEventHandler:run()
    self.config.comember_cache:hold(self.player)
    gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', self.player)
end

GwOfflineSystemEventHandler = GwSystemEventHandler:new()

function GwOfflineSystemEventHandler:run()
    self.config.comember_cache:hold(self.player)
    gw.Debug(GW_LOG_DEBUG, 'comember_cache: updated %s', self.player)
end

GwJoinSystemEventHandler = GwSystemEventHandler:new()

function GwJoinSystemEventHandler:run()
    if self.player == gw.player then
        gw.Debug(GW_LOG_NOTICE, 'guild join detected.')
        self.config.channel.guild:send(GW_MTYPE_BROADCAST, 'join')
    end
end

GwLeaveSystemEventHandler = GwSystemEventHandler:new()

function GwLeaveSystemEventHandler:run()
    if self.player == gw.player then
        gw.Debug(GW_LOG_NOTICE, 'guild quit detected.')
        self.config.channel.guild:send(GW_MTYPE_BROADCAST, 'leave')
        self.config:reset()
    end
end

GwQuitSystemEventHandler = GwSystemEventHandler:new()

function GwQuitSystemEventHandler:run()
    gw.Debug(GW_LOG_NOTICE, 'guild quit detected.')
    self.config.channel.guild:send(GW_MTYPE_BROADCAST, 'leave')
    self.config:reset()
end

GwRemoveSystemEventHandler = GwSystemEventHandler:new()

function GwRemoveSystemEventHandler:run()
    if self.player == gw.player then
        gw.Debug(GW_LOG_NOTICE, 'guild kick detected.')
        self.config.channel.guild:send(GW_MTYPE_BROADCAST, 'remove')
        self.config:reset()
    end
end

GwKickSystemEventHandler = GwSystemEventHandler:new()

function GwKickSystemEventHandler:run()
    gw.Debug(GW_LOG_NOTICE, 'guild kick detected.')
    self.config.channel.guild:send(GW_MTYPE_BROADCAST, 'leave')
    self.config:reset()
end

GwPromoteSystemEventHandler = GwSystemEventHandler:new()

function GwSystemEventHandler:factory(config, message)
    -- Remove coloring
    message = string.gsub(message, "|c%w%w%w%w%w%w%w%w([^|]*)|r", "%1")

    if message:match(pat_online) then

        local _, player = message:match(pat_online)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player online: %s', player)
        return GwOnlineSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_online_raw) then

        local player = message:match(pat_online_raw)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player online: %s', player)
        return GwOnlineSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_offline) then

        local player = message:match(pat_offline)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player offline: %s', player)
        return GwOfflineSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_join) then

        local player = message:match(pat_join)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player join: %s', player)
        return GwJoinSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_leave) then

        local player = message:match(pat_leave)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player leave: %s', player)
        return GwLeaveSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_quit) then

        local player = UnitName('player')
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player leave: %s', player)
        return GwQuitSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_removed) then

        local player = message:match(pat_removed)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player removed: %s', player)
        return GwRemoveSystemEventHandler:new({ config = config, player = player })

    elseif message:match(pat_kick) then

        local player = UnitName('player')
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player removed: %s', player)
        return GwKickSystemEventHandler:new({ config = config, player = player })

    else

        -- Unhandled system message
        return GwSystemEventHandler:new({ config = config })

    end

end