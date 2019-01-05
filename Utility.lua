--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2019 Mark Rogaski

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


---------------------------------------------------------------------------
-- Logic functions
---------------------------------------------------------------------------

--- Case insensitive string comparison.
-- @param a A string
-- @param b A string
-- @return True if the strings match in all respects except case, false otherwise.
function gw.iCmp(a, b)
    if string.lower(a) == string.lower(b) then
        return true
    else
        return false
    end
end


---------------------------------------------------------------------------
-- Logging functions
---------------------------------------------------------------------------

--- Add a message to the log file
-- @param msg A string to write to the log.
function gw.Log(msg)
    if gw.settings and gw.settings:get('log') then
        local ts = date('%Y-%m-%d %H:%M:%S')
        tinsert(GreenWallLog, format('%s -- %s', ts, msg))
        while # GreenWallLog > gw.settings:get('logsize') do
            tremove(GreenWallLog, 1)
        end
    end
end


--- Write a message to the default chat frame.
-- @param ... A list of the string and arguments for substitution using the syntax of string.format.
function gw.Write(...)
    local msg = string.format(unpack({...}))
    DEFAULT_CHAT_FRAME:AddMessage('|cff0bda51GreenWall:|r ' .. msg)
    gw.Log(msg)
end


--- Write an error message to the default chat frame.
-- @param ... A list of the string and arguments for substitution using the syntax of string.format.
function gw.Error(...)
    local msg = string.format(unpack({...}))
    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r |cffff6000[ERROR] ' .. msg)
    gw.Log('[ERROR] ' .. msg)
end


--- Write a debugging message to the default chat frame with a detail level.
-- Messages will be filtered with the "/greenwall debug <level>" command.
-- @param level A positive integer specifying the debug level to display this under.
-- @param ... A list of the string and arguments for substitution using the syntax of string.format.
function gw.Debug(level, ...)
    local function get_caller()
        local s = debugstack(3, 1, 0)
        local loc = strmatch(s, '([%a%._-]+:%d+): in function')
        local fun = strmatch(s, 'in function \`([%a_-]+)\'')
        return fun and loc .. '(' .. fun .. ')' or loc
    end

    if gw.settings then
        if level <= gw.settings:get('debug') then
            local msg = string.format(unpack({...}))
            local trace = format('[debug/%d@%s] %s', level, get_caller(), msg)
            gw.Log(trace)
            if gw.settings:get('verbose') then
                DEFAULT_CHAT_FRAME:AddMessage(format('|cff009a7dGreenWall:|r |cff778899%s|r', trace))
            end
        end
    end
end


--- Print an obfuscated string if the redaction option is set.
-- @param msg The input string
-- @return The string with redaction applied, if necessary.
function gw.Redact(msg)
    if gw.settings:get('redact') then
        return string.format('<<%04X>>', crc.Hash(msg))
    else
        return msg
    end
end


---------------------------------------------------------------------------
-- Game functions
---------------------------------------------------------------------------

--- Format name for cross-realm addressing.
-- @param name Character name or guild name.
-- @param realm Name of the realm.
-- @return A formatted cross-realm address.
function gw.GlobalName(name, realm)
    -- Pass formatted names without modification.
    if name:match("[^-]+-[^-]+$") then
        return name
    end

    -- Use local realm as the default.
    if realm == nil then
        realm = GetRealmName()
    end

    return name .. '-' .. realm:gsub("%s+", "")

end


--- Get the player's fully-qualified guild name.
-- @param target (optional) unit ID, default is 'Player'.
-- @return A qualified guild name or nil if the player is not in a guild.
function gw.GetGuildName(target)
    if target == nil then
        target = 'Player'
    end
    local name, _, _, realm = GetGuildInfo(target)
    if name == nil then
        return
    end
    return gw.GlobalName(name, realm)
end


--- Get a string with the player's fully-qualified guild name and numeric rank.
-- @return A string identifier, the empty string if not in a guild.
function gw.GetGuildStatus()
    local name, _, rank, realm = GetGuildInfo('Player')
    if name == nil then
        return ''
    else
        return string.format('%s-%d', gw.GlobalName(name, realm), rank)
    end
end


--- Check a target player for officer status in the same container guild.
-- @param target The name of the player to check.
-- @return True if the target has at least read access to officer chat and officer notes, false otherwise.
function gw.IsOfficer(target)
    local function get_rank(target)
        local guild, name, rank
        if target == nil or gw.GlobalName(target) == gw.player then
            guild, name, rank = GetGuildInfo('player')
            if guild then
                gw.Debug(GW_LOG_DEBUG, 'target=%s, rank=%s (%s)', gw.player, rank, name)
                return rank + 1
            else
                gw.Debug(GW_LOG_DEBUG, 'target=%s not in a guild', gw.player)
                return
            end
        else
            local n = GetNumGuildMembers()
            for i = 1, n do
                local candidate
                candidate, name, rank = GetGuildRosterInfo(i)
                if gw.GlobalName(candidate) == gw.GlobalName(target) then
                    gw.Debug(GW_LOG_DEBUG, 'target=%s, rank=%s (%s)', target, rank, name)
                    return rank + 1
                end
            end
        end
        gw.Debug(GW_LOG_DEBUG, 'target=%s not in a guild', target)
        return
    end

    -- Workaround for 7.3.0, where GuildControlSetRank() is protected.
    local note = gw.GetGMOfficerNote()
    local result = false
    if note ~= nil and note ~= '' then
        result = true
    end
    gw.Debug(GW_LOG_INFO, 'is_officer: %s', tostring(result))

    return result
end


--- Get the officer note for the GM, if possible.
-- @return The officer note of the GM as a string, or nil.
function gw.GetGMOfficerNote()
    local n = GetNumGuildMembers();
    local name, rank, note
    for i = 1, n do
        name, _, rank, _, _, _, _, note = GetGuildRosterInfo(i);
        if rank == 0 then
            return note;
        end
    end
    return
end


--- Check if player is currently in any world channels.
-- @return True is the player has joined any world channels, false otherwise.
function gw.WorldChannelFound()
    gw.Debug(GW_LOG_DEBUG, 'scanning for world channels')
    for i, v in pairs({GetChannelList()}) do
        local name, header, _, _, _, _, category = GetChannelDisplayInfo(i)
        if not header then
            if category == 'CHANNEL_CATEGORY_WORLD' then
                gw.Debug(GW_LOG_DEBUG, 'world channel found: %s', name)
                return true
            end
        end
    end
    return false
end


---------------------------------------------------------------------------
-- Item functions
---------------------------------------------------------------------------

--- Extract an embedded itemString from a chat message.
-- @param message A chat message.
-- @return An itemString.
function gw.GetItemString(message)
    return string.match(message, '|H(item[0-9:]+)|h')
end

--- Extract an embedded itemString from a chat message.
-- @param item An itemString.
-- @return True is the item is legendary.
function gw.IsLegendary(item)
    _, _, rarity = GetItemInfo(item)
    if rarity == 5 then
        return true
    else
        return false
    end
end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
