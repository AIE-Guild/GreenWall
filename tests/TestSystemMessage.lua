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
-- Test Cases
--

TestSystemMessage = {}

function TestSystemMessage:test_online()
    message = "|Hplayer:Eggolas|h[Eggolas]|h has come online."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwOnlineSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_online_raw()
    message = "Eggolas has come |cff298F00online|r."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwOnlineSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_offline()
    message = "Eggolas has gone offline."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwOfflineSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_join()
    message = "Eggolas has joined the guild."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwJoinSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_leave()
    message = "Eggolas has left the guild."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwLeaveSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_quit()
    message = "You are no longer a member of SparkleMotion."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwQuitSystemMessage)
    lu.assertEquals(sysmsg.player, "Ralff-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_remove()
    message = "Eggolas has been kicked out of the guild by Ralff."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwRemoveSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_kick()
    message = "You have been kicked out of the guild."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwKickSystemMessage)
    lu.assertEquals(sysmsg.player, "Ralff-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemMessage:test_promote()
    message = "Rallf has promoted Eggolas to Cohort."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwPromoteSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertEquals(sysmsg.rank, "Cohort")
end

function TestSystemMessage:test_demote()
    message = "Rallf has demoted Eggolas to Pleb."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwDemoteSystemMessage)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertEquals(sysmsg.rank, "Pleb")
end

function TestSystemMessage:test_no_match()
    message = "Don't panic."
    sysmsg = GwSystemMessage:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwSystemMessage)
    lu.assertNil(sysmsg.player)
    lu.assertNil(sysmsg.rank)
end


--
-- Run the tests
--

os.exit(lu.run())
