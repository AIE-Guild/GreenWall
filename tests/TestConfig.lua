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
-- GwConfig:load() - guild info text should prefer the namespaced API
-- (C_GuildInfo.GetInfoText) and fall back to the deprecated global
-- (GetGuildInfoText).
--

TestConfigInfoText = {}

function TestConfigInfoText:setUp()
    self.saved = {
        C_GuildInfo = C_GuildInfo,
        GetGuildInfoText = GetGuildInfoText,
        GetGuildName = gw.GetGuildName,
        version = gw.version,
        settings = gw.settings,
        time = time,
    }
    gw.settings = GwSettings:new()
    gw.version = '1.0.0'
    gw.GetGuildName = function() return 'TestGuild' end
    time = os.time
end

function TestConfigInfoText:tearDown()
    C_GuildInfo = self.saved.C_GuildInfo
    GetGuildInfoText = self.saved.GetGuildInfoText
    gw.GetGuildName = self.saved.GetGuildName
    gw.version = self.saved.version
    gw.settings = self.saved.settings
    time = self.saved.time
end

function TestConfigInfoText:test_prefers_C_GuildInfo()
    local source
    C_GuildInfo = { GetInfoText = function()
        source = 'namespaced'
        return 'GW:c:Chan:pass\nGW:v:1.0.0\n'
    end }
    GetGuildInfoText = function()
        source = 'global'
        return 'GW:c:Chan:pass\nGW:v:1.0.0\n'
    end
    GwConfig:new():load()
    lu.assertEquals(source, 'namespaced')
end

function TestConfigInfoText:test_falls_back_to_global_when_absent()
    local source
    C_GuildInfo = nil
    GetGuildInfoText = function()
        source = 'global'
        return 'GW:c:Chan:pass\nGW:v:1.0.0\n'
    end
    GwConfig:new():load()
    lu.assertEquals(source, 'global')
end

function TestConfigInfoText:test_falls_back_when_method_missing()
    local source
    C_GuildInfo = {}    -- table present, but no GetInfoText field
    GetGuildInfoText = function()
        source = 'global'
        return 'GW:c:Chan:pass\nGW:v:1.0.0\n'
    end
    GwConfig:new():load()
    lu.assertEquals(source, 'global')
end


--
-- GwConfig:is_container() called self:GetGuildName(), which GwConfig does not define, so every
-- call raised.  And a version the regex accepted but semver() rejects aborted the whole parse.
--

TestConfigContainer = {}

function TestConfigContainer:setUp()
    self.saved = { GetGuildName = gw.GetGuildName }
    gw.GetGuildName = function() return 'TestGuild' end
end

function TestConfigContainer:tearDown()
    gw.GetGuildName = self.saved.GetGuildName
end

function TestConfigContainer:test_own_guild_is_in_the_confederation()
    local config = GwConfig.initialize_param({})
    config.guild_id = 'TG'
    config.is_peer = GwConfig.is_peer
    config.is_container = GwConfig.is_container
    lu.assertTrue(config:is_container('TestGuild'))
end

function TestConfigContainer:test_peer_is_in_the_confederation()
    local config = GwConfig.initialize_param({})
    config.guild_id = 'TG'
    config.peer = { DA = 'Dead Air' }
    config.is_peer = GwConfig.is_peer
    config.is_container = GwConfig.is_container
    lu.assertTrue(config:is_container('Dead Air'))
    lu.assertFalse(config:is_container('Some Randoms'))
end

function TestConfigContainer:test_own_guild_without_a_tag_is_not_configured()
    local config = GwConfig.initialize_param({})
    config.is_peer = GwConfig.is_peer
    config.is_container = GwConfig.is_container
    lu.assertFalse(config:is_container('TestGuild'))
end


TestConfigVersionDirective = {}

function TestConfigVersionDirective:setUp()
    self.saved = {
        GetGuildInfoText = GetGuildInfoText,
        GetGuildName = gw.GetGuildName,
        version = gw.version,
        settings = gw.settings,
        time = time,
    }
    gw.settings = GwSettings:new()
    -- Above any minimum these cases configure, so load() does not take the version-warning path
    -- (gw.Error needs a DEFAULT_CHAT_FRAME that the mock does not provide).
    gw.version = '9.9.9'
    gw.GetGuildName = function() return 'TestGuild' end
    time = os.time
end

function TestConfigVersionDirective:tearDown()
    GetGuildInfoText = self.saved.GetGuildInfoText
    gw.GetGuildName = self.saved.GetGuildName
    gw.version = self.saved.version
    gw.settings = self.saved.settings
    time = self.saved.time
end

local function info(...)
    return table.concat({ ... }, '\n') .. '\n'
end

function TestConfigVersionDirective:test_valid_minimum_version_is_recorded()
    GetGuildInfoText = function()
        return info('GW:c:Chan:pass', 'GW:v:1.2.3')
    end
    local config = GwConfig:new()
    lu.assertTrue(config:load())
    lu.assertEquals(config.minimum, '1.2.3')
end

function TestConfigVersionDirective:test_unparseable_version_does_not_abort_the_parse()
    -- '1.2.3beta' passes a '^%d+%.%d+%.%d+%w*$' regex but semver() rejects it, and tostring()
    -- with no argument then raised -- taking down the whole configuration over one mistyped line.
    -- The directives after the bad line must still be read.
    GetGuildInfoText = function()
        return info('GW:c:Chan:pass', 'GW:v:1.2.3beta', 'GW:p:Dead Air:DA')
    end
    local config = GwConfig:new()
    lu.assertTrue(config:load())
    lu.assertEquals(config.minimum, '')
    lu.assertEquals(config.peer['DA'], gw.GlobalName('Dead Air'))
end

--
-- Run the tests
--

os.exit(lu.run())
