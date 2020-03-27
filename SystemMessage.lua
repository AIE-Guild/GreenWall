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
local pat_promote = ERR_GUILD_PROMOTE_SSS:format('(.+)', '(.+)', '(.+)')
local pat_demote = ERR_GUILD_DEMOTE_SSS:format('(.+)', '(.+)', '(.+)')

GwSystemMessage = { player = nil, rank = nil }

function GwSystemMessage:new(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

GwOnlineSystemMessage = GwSystemMessage:new()

GwOfflineSystemMessage = GwSystemMessage:new()

GwJoinSystemMessage = GwSystemMessage:new()

GwLeaveSystemMessage = GwSystemMessage:new()

GwQuitSystemMessage = GwSystemMessage:new()

GwRemoveSystemMessage = GwSystemMessage:new()

GwKickSystemMessage = GwSystemMessage:new()

GwPromoteSystemMessage = GwSystemMessage:new()

GwDemoteSystemMessage = GwSystemMessage:new()

function GwSystemMessage:factory(message)
    -- Remove coloring
    message = string.gsub(message, "|c%w%w%w%w%w%w%w%w([^|]*)|r", "%1")

    if message:match(pat_online) then

        local _, player = message:match(pat_online)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player online: %s', player)
        return GwOnlineSystemMessage:new({ player = player })

    elseif message:match(pat_online_raw) then

        local player = message:match(pat_online_raw)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player online: %s', player)
        return GwOnlineSystemMessage:new({ player = player })

    elseif message:match(pat_offline) then

        local player = message:match(pat_offline)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player offline: %s', player)
        return GwOfflineSystemMessage:new({ player = player })

    elseif message:match(pat_join) then

        local player = message:match(pat_join)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player join: %s', player)
        return GwJoinSystemMessage:new({ player = player })

    elseif message:match(pat_leave) then

        local player = message:match(pat_leave)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player leave: %s', player)
        return GwLeaveSystemMessage:new({ player = player })

    elseif message:match(pat_quit) then

        local player = UnitName('player')
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player leave: %s', player)
        return GwQuitSystemMessage:new({ player = player })

    elseif message:match(pat_removed) then

        local player = message:match(pat_removed)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player removed: %s', player)
        return GwRemoveSystemMessage:new({ player = player })

    elseif message:match(pat_kick) then

        local player = UnitName('player')
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player removed: %s', player)
        return GwKickSystemMessage:new({ player = player })

    elseif message:match(pat_promote) then

        local _, player, rank = message:match(pat_promote)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player promoted: %s, %s', player, rank)
        return GwPromoteSystemMessage:new({ player = player, rank = rank })

    elseif message:match(pat_demote) then

        local _, player, rank = message:match(pat_demote)
        player = gw.GlobalName(player)
        gw.Debug(GW_LOG_NOTICE, 'player demoted: %s, %s', player, rank)
        return GwDemoteSystemMessage:new({ player = player, rank = rank })

    else

        -- Unhandled system message
        return GwSystemMessage:new()

    end

end