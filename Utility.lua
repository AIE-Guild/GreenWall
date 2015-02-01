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
    if GreenWall ~= nil and GreenWall.log and GreenWallLog ~= nil then
        local ts = date('%Y-%m-%d %H:%M:%S')
        tinsert(GreenWallLog, format('%s -- %s', ts, msg))
        while # GreenWallLog > GreenWall.logsize do
            tremove(GreenWallLog, 1)
        end
    end
end


--- Write a message to the default chat frame.
-- @param ... A list of the string and arguments for substitution using the syntax of string.format.
function gw.Write(...)
    local msg = string.format(unpack({...}))
    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r ' .. msg)
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
    local msg = string.format(unpack({...}))
    if GreenWall ~= nil then
        if level <= GreenWall.debug then
            gw.Log(format('[DEBUG/%d] %s', level, msg))
            if GreenWall.verbose then
                DEFAULT_CHAT_FRAME:AddMessage(format('|cffabd473GreenWall:|r |cff778899[DEBUG/%d] %s|r', level, msg))
            end
        end
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
    if name:match(".+-[%a']+$") then
        return name
    end

    -- Use local realm as the default.
    if realm == nil then
        realm = GetRealmName()
    end

    return name .. '-' .. realm:gsub("%s+", "")

end


--- Get the player's fully-qualified name.
-- @return A qualified player name.
function gw.GetPlayerName(target)
    return UnitName('player') .. '-' .. gwRealmName:gsub("%s+", "")
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


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
