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

lu = require('luaunit')
require('Loader')


--
-- GwConfig:load() cleanup - self.channel is keyed by 'guild'/'officer', so a
-- stale channel must be cleared via pairs(); an ipairs() cleanup would silently
-- skip the whole (hash-keyed) table and leave stale channels behind.
--

TestConfigCleanup = {}

local function stub_channel(stale)
    return {
        aged = false, configured = false, cleared = false,
        age       = function(self) self.aged = true end,
        configure = function(self) self.configured = true end,
        is_stale  = function(self) return stale end,
        clear     = function(self) self.cleared = true end,
    }
end

function TestConfigCleanup:setUp()
    self.saved = {
        GetGuildInfoText = GetGuildInfoText,
        GetGuildName = gw.GetGuildName,
        version = gw.version,
        settings = gw.settings,
        time = time,
    }
    gw.settings = GwSettings:new()
    gw.version = '1.0.0'
    gw.GetGuildName = function() return 'TestGuild' end
    GetGuildInfoText = function() return 'GW:c:Chan:pass\nGW:v:1.0.0\n' end
    time = os.time   -- config timers call time(); any monotonic value is fine
end

function TestConfigCleanup:tearDown()
    GetGuildInfoText = self.saved.GetGuildInfoText
    gw.GetGuildName = self.saved.GetGuildName
    gw.version = self.saved.version
    gw.settings = self.saved.settings
    time = self.saved.time
end

function TestConfigCleanup:test_stale_channel_is_cleared()
    local config = GwConfig:new()
    config.channel = { guild = stub_channel(true), officer = stub_channel(false) }
    config:load()
    -- The stale guild channel (hash key 'guild') must be reached and cleared.
    lu.assertTrue(config.channel.guild.cleared)
end


--
-- Run the tests
--

os.exit(lu.run())
