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

An API for guild chat bridging as a transport

--]]-----------------------------------------------------------------------

--
-- Global to expose API
--
GreenWallAPI = {
    version = 1,
}


--- Send a message to the guild confederation.
-- @param addon The addon name (the same one used for the name of the TOC
--  file).
-- @param message The message to send. Accepts 8-bit data.
function GreenWallAPI.SendMessage(addon, message)
    -- Validate addon id
    assert(addon == GetAddOnInfo(addon))
    gw.config.channel.guild:send(GW_MTYPE_EXTERNAL, addon, message)
end


--- Insert a handler for addon messages from the guild confederation.
-- @param handler A callback function.
-- @param addon The name of the addon that you want to receive meaasges from
--  (the same one used for the name of the TOC file).  If the value '*' is
--  supplied, messages from all addons will be handled.
-- @param priority A signed integer indicating relative priority, lower value
--  is handled first.  The default is 0.
-- @return The ID that can be used to remove the handler.
function GreenWallAPI.AddMessageHandler(handler, addon, priority)
    local function generate_id(handler)
        local count = 0
        for _, e in ipairs(gw.api_table) do
            if handler == e[4] then
                count = count + 1
            end
        end
        return string.format('%s:%04X', tostring(handler), count)
    end

    -- Validate the arguments
    assert(priority % 1 == 0)
    if addon ~= '*' then
        assert(addon == GetAddOnInfo(addon))
    end

    local id = generate_id(handler)
    gw.Debug(GW_LOG_INFO, 'add API handler; id=%s, addon=%s, priority=%d', id, addon, priority)

    table.insert(gw.api_table, {id, addon, priority, handler})
    table.sort(gw.api_table, function (a, b) return a[2] < b[2] end)

    return id
end


--- Remove an addon message handler.
-- @param id The ID of the callback function to remove.
-- @return True if a matching handler is found, false otherwise.
function GreenWallAPI.RemoveMessageHandler(id)
    rv = false
    if addon ~= '*' then
        addon = GetAddOnInfo(addon)
        assert(addon ~=nil)
    end
    for i, e in ipairs(gw.api_table) do
        if id == e[1] then
            gw.Debug(GW_LOG_INFO, 'remove API handler; id=%, addon=%s, priority=%d', e[1], e[2], e[3])
            gw.api_table[i] = nil
            return true
        end
    end
    return false
end


--- Clear our portions or all of the dispatch table entries.
-- @param addon Optional identifier for the addon or '*'.  If nil,
--  all table entries will be removed.
--
-- Note: A '*' value passed as addon is not a wildcard in this context,
-- it will only matche instances where the handler was installed with
-- '*' as the addon.
function GreenWallAPI.ClearMessageHandlers(addon)
    if addon == nil then
        gw.Debug(GW_LOG_INFO, 'remove all API handlers')
        gw.api_table = {}
    else
        if addon ~= '*' then
            assert(addon == GetAddOnInfo(addon))
        end
        for i, e in ipairs(gw.api_table) do
            if addon == e[2] then
                gw.Debug(GW_LOG_INFO, 'remove API handler; id=%, addon=%s, priority=%d', e[1], e[2], e[3])
                gw.api_table[i] = nil
            end
        end
    end
end


--- The API handler dispatcher
-- @param addon The sending addon
-- @param sender The sending player
-- @param guild_id Originating co-guild
-- @param message The message contents
function gw.APIDispatcher(addon, sender, guild_id, message)
    local echo = sender == gw.player
    local guild = guild_id == gw.config.guild_id
    for _, e in ipairs(gw.api_table) do
        if addon == e[2] or addon == '*' then
            gw.Debug(GW_LOG_INFO, 'dispatch API handler; id=%s, addon=%s, priority=%d', e[1], e[2], e[3])
            e[4](addon, sender, message, echo, guild)
        end
    end
end
