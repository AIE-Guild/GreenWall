--[[--------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2017 Mark Rogaski

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
require('TestCompat')
require('ClassLib')
require('Constants')
require('Lib/LibStub')
require('Lib/SemanticVersion')
require('Config')

--
-- Mocks
--

gw = { logmsg = '' }

function gw.Debug(level, format, ...)
    gw.logmsg = string.format(format, ...)
end


--
-- Test Cases
--

TestConfig = {}

function TestConfig:test_new()
    local config = GwConfig:new()
    lu.assertTrue(config:isa(GwConfig))
    lu.assertEquals(config.version, nil)
    lu.assertEquals(config.guild_name, nil)
    lu.assertEquals(config.guild_id, nil)
    lu.assertEquals(config.channel.guild, nil)
    lu.assertEquals(config.channel.officer, nil)
    lu.assertEquals(config.peer, {})
    lu.assertEquals(config.minimum_version, nil)
end


TestConfigBuilder = {}

function TestConfigBuilder:test_new()
    local builder = GwConfigBuilder:new()
    lu.assertTrue(builder:isa(GwConfigBuilder))
end

function TestConfigBuilder:test_get_config()
    local builder = GwConfigBuilder:new()
    local config = builder:get_config()
    lu.assertTrue(config:isa(GwConfig))
end

function TestConfigBuilder:test_set_version()
    local builder = GwConfigBuilder:new()
    builder:set_version(1)
    lu.assertEquals(builder:get_config().version, 1)
    builder:set_version(2)
    lu.assertEquals(builder:get_config().version, 2)
    lu.assertError(builder.set_version, builder, 3)
end

function TestConfigBuilder:test_set_guild_name()
    local builder = GwConfigBuilder:new()
    builder:set_guild_name('Blue Sun')
    lu.assertEquals(builder:get_config().guild_name, 'Blue Sun')
    lu.assertError(builder.set_guild_name, '')
    lu.assertError(builder.set_guild_name, nil)
end

function TestConfigBuilder:test_set_guild_id()
    local builder = GwConfigBuilder:new()
    builder:set_guild_id('bsun')
    lu.assertEquals(builder:get_config().guild_id, 'bsun')
    lu.assertError(builder.set_guild_id, '')
    lu.assertError(builder.set_guild_id, nil)
end

function TestConfigBuilder:test_set_guild_channel()
    local builder = GwConfigBuilder:new()

    builder:set_guild_channel('someChannel')
    lu.assertEquals(builder:get_config().channel.guild,
        {name = 'someChannel'})

    builder:set_guild_channel('someChannel', 'p@ssw0rd')
    lu.assertEquals(builder:get_config().channel.guild,
        {name = 'someChannel', password = 'p@ssw0rd'})

    builder:set_guild_channel('someChannel', 'p@ssw0rd', 'sekrit')
    lu.assertEquals(builder:get_config().channel.guild,
        { name = 'someChannel', password = 'p@ssw0rd', key = 'sekrit'})

    builder:set_guild_channel('someChannel', 'p@ssw0rd', 'sekrit', 1)
    lu.assertEquals(builder:get_config().channel.guild,
        { name = 'someChannel', password = 'p@ssw0rd', key = 'sekrit', cipher = 1})

    lu.assertError(builder.set_guild_channel, '')
    lu.assertError(builder.set_guild_channel, nil)
end

function TestConfigBuilder:test_set_officer_channel()
    local builder = GwConfigBuilder:new()

    builder:set_officer_channel('someChannel')
    lu.assertEquals(builder:get_config().channel.officer,
        {name = 'someChannel'})

    builder:set_officer_channel('someChannel', 'p@ssw0rd')
    lu.assertEquals(builder:get_config().channel.officer,
        {name = 'someChannel', password = 'p@ssw0rd'})

    builder:set_officer_channel('someChannel', 'p@ssw0rd', 'sekrit')
    lu.assertEquals(builder:get_config().channel.officer,
        { name = 'someChannel', password = 'p@ssw0rd', key = 'sekrit'})

    builder:set_officer_channel('someChannel', 'p@ssw0rd', 'sekrit', 1)
    lu.assertEquals(builder:get_config().channel.officer,
        { name = 'someChannel', password = 'p@ssw0rd', key = 'sekrit', cipher = 1})

    lu.assertError(builder.set_officer_channel, '')
    lu.assertError(builder.set_officer_channel, nil)
end

function TestConfigBuilder:test_set_peer()
    local builder = GwConfigBuilder:new()
    builder:set_peer('coga', 'Guild A')
    builder:set_peer('cogb', 'Guild B')
    builder:set_peer('cogc', 'Guild C')
    lu.assertEquals(builder:get_config().peer, {coga="Guild A", cogb="Guild B", cogc="Guild C"})
    lu.assertError(builder.set_peer, '')
    lu.assertError(builder.set_peer, nil)
end

function TestConfigBuilder:test_set_minimum_version()
    local builder = GwConfigBuilder:new()
    builder:set_minimum_version('1.9.0-beta')
    lu.assertEquals(builder:get_config().minimum_version, {major=1, meta={}, minor=9, patch=0, pre={"beta"}})
    lu.assertError(builder.set_minimum_version, '')
    lu.assertError(builder.set_minimum_version, nil)
end


--
-- Run the tests
--

os.exit(lu.run())