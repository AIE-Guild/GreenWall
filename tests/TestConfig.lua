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
-- Run the tests
--

os.exit(lu.run())
