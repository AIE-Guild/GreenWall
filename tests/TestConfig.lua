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


function TestConfigBuilder:test_version()
    local builder = GwConfigBuilder:new()
    builder:set_version(1)
    lu.assertEquals(builder:get_config().version, 1)
    builder:set_version(2)
    lu.assertEquals(builder:get_config().version, 2)
    lu.assertError(builder.set_version, builder, 3)
end

--
-- Run the tests
--

os.exit(lu.run())