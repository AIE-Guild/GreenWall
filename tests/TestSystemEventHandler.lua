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
-- Includes
--

lu = require('luaunit')
require('Loader')

--
-- Mocks
--
local MockChan = {}
MockChan.__index = MockChan

function MockChan:new()
    local self = {}
    setmetatable(self, MockChan)
    self.input = {}
    return self
end

function MockChan:send(mtype, ...)
    table.insert(self.input, { mtype, ... })
end

local MockCache = {}
MockCache.__index = MockCache

function MockCache:new(output)
    local self = {}
    setmetatable(self, MockCache)
    self.input = {}
    self.output = output and true or false
    return self
end

function MockCache:hold(s)
    table.insert(self.input, s)
    return self.output
end

local MockConfig = {}
MockConfig.__index = MockConfig

function MockConfig:new(holddown)
    local self = {}
    setmetatable(self, MockConfig)
    self.channel = { guild = MockChan:new() }
    self.comember_cache = MockCache:new(holddown)
    self.is_reset = false
    return self
end

function MockConfig:reset()
    self.is_reset = true
end


--
-- Test Cases
--

TestSystemEventHandler = {}

function TestSystemEventHandler:test_online_init()
    config = MockConfig:new()
    message = "|Hplayer:Eggolas|h[Eggolas]|h has come online."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwOnlineSystemEventHandler)
    lu.assertEquals(handler.player, "Eggolas-EarthenRing")
    lu.assertEquals(handler.config, config)
end

function TestSystemEventHandler:test_online_raw_init()
    config = MockConfig:new()
    message = "Eggolas has come |cff298F00online|r."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwOnlineSystemEventHandler)
    lu.assertEquals(handler.player, "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_online_run()
    config = MockConfig:new()
    message = "|Hplayer:Eggolas|h[Eggolas]|h has come online."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.comember_cache.input[1], "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_online_run_cached()
    config = MockConfig:new(true)
    message = "|Hplayer:Eggolas|h[Eggolas]|h has come online."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.comember_cache.input[1], "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_offline_init()
    config = MockConfig:new()
    message = "Eggolas has gone offline."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwOfflineSystemEventHandler)
    lu.assertEquals(handler.player, "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_offline_run()
    config = MockConfig:new()
    message = "Eggolas has gone offline."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.comember_cache.input[1], "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_offline_run_cached()
    config = MockConfig:new(true)
    message = "Eggolas has gone offline."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.comember_cache.input[1], "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_join_init()
    config = MockConfig:new()
    message = "Eggolas has joined the guild."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwJoinSystemEventHandler)
    lu.assertEquals(handler.player, "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_join_run()
    config = MockConfig:new()
    message = "Ralff has joined the guild."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.channel.guild.input[1], { GW_MTYPE_BROADCAST, "join" })
end

function TestSystemEventHandler:test_join_run_skip()
    config = MockConfig:new()
    message = "Eggolas has joined the guild."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertNil(config.channel.guild.input[1])
end

function TestSystemEventHandler:test_leave_init()
    config = MockConfig:new()
    message = "Eggolas has left the guild."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwLeaveSystemEventHandler)
    lu.assertEquals(handler.player, "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_leave_run()
    config = MockConfig:new()
    message = "Ralff has left the guild."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.channel.guild.input[1], { GW_MTYPE_BROADCAST, "leave" })
    lu.assertTrue(config.is_reset)
end

function TestSystemEventHandler:test_leave_run_skip()
    config = MockConfig:new()
    message = "Eggolas has left the guild."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertNil(config.channel.guild.input[1])
    lu.assertFalse(config.is_reset)
end

function TestSystemEventHandler:test_quit_init()
    config = MockConfig:new()
    message = "You are no longer a member of SparkleMotion."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwQuitSystemEventHandler)
    lu.assertEquals(handler.player, "Ralff-EarthenRing")
end

function TestSystemEventHandler:test_quit_run()
    config = MockConfig:new()
    message = "You are no longer a member of SparkleMotion."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.channel.guild.input[1], { GW_MTYPE_BROADCAST, "leave" })
    lu.assertTrue(config.is_reset)
end

function TestSystemEventHandler:test_remove_init()
    config = MockConfig:new()
    message = "Eggolas has been kicked out of the guild by Ralff."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwRemoveSystemEventHandler)
    lu.assertEquals(handler.player, "Eggolas-EarthenRing")
end

function TestSystemEventHandler:test_remove_run()
    config = MockConfig:new()
    message = "Ralff has been kicked out of the guild by Eggolas."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.channel.guild.input[1], { GW_MTYPE_BROADCAST, "remove" })
    lu.assertTrue(config.is_reset)
end

function TestSystemEventHandler:test_remove_run_skip()
    config = MockConfig:new()
    message = "Eggolas has been kicked out of the guild by Ralff."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertNil(config.channel.guild.input[1])
    lu.assertFalse(config.is_reset)
end

function TestSystemEventHandler:test_kick_init()
    config = MockConfig:new()
    message = "You have been kicked out of the guild."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwKickSystemEventHandler)
    lu.assertEquals(handler.player, "Ralff-EarthenRing")
end

function TestSystemEventHandler:test_kick_run()
    config = MockConfig:new()
    message = "You have been kicked out of the guild."
    handler = GwSystemEventHandler:factory(config, message)
    handler:run()
    lu.assertEquals(config.channel.guild.input[1], { GW_MTYPE_BROADCAST, "leave" })
    lu.assertTrue(config.is_reset)
end

function TestSystemEventHandler:test_no_match()
    config = MockConfig:new()
    message = "Don't panic."
    handler = GwSystemEventHandler:factory(config, message)
    lu.assertEquals(getmetatable(handler), GwSystemEventHandler)
    lu.assertNil(handler.player)
end


--
-- Run the tests
--

os.exit(lu.run())
