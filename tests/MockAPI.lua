--[[--------------------------------------------------------------------------

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

--]]--------------------------------------------------------------------------

--
-- These functions adapt or mock Lua extensions in the WoW API.
--
require('bit')

-- Read the TOC file
local TOC = {}
f = io.open('GreenWall.toc')
while true do
    line = f:read()
    if line == nil then
        break
    end
    k, v = string.match(line, '## (%a+): (.*)%s*$')
    if k ~= nil then
        TOC[k] = v
    end
end
f:close()

--
-- Constants
--
ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h has come online."
ERR_FRIEND_OFFLINE_S = "%s has gone offline."
ERR_GUILD_JOIN_S = "%s has joined the guild."
ERR_GUILD_LEAVE_S = "%s has left the guild."
ERR_GUILD_QUIT_S = "You are no longer a member of %s."
ERR_GUILD_REMOVE_SS = "%s has been kicked out of the guild by %s."
ERR_GUILD_REMOVE_SELF = "You have been kicked out of the guild."
ERR_GUILD_PROMOTE_SSS = "%s has promoted %s to %s."
ERR_GUILD_DEMOTE_SSS = "%s has demoted %s to %s."

function date(...)
    return os.date(...)
end

function strmatch(...)
    return string.match(...)
end

function GetAddOnMetadata(addon, field)
    if addon == TOC['Title'] then
        return TOC['Version']
    end
    return
end

function GetRealmName()
    return 'EarthenRing'
end

function UnitName(target)
    if target == 'player' then
        return 'Ralff'
    end
    return
end

function GetBuildInfo()
    x, y, z = string.match(TOC['Interface'], '(%d)(%d%d)(%d%d)')
    version = string.format('%d.%d.%d', x, y, z)
    return version, '12345', os.date(), TOC['Interface']
end

function hooksecurefunc(...)
    return
end
